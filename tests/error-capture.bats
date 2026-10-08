#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"
bats_require_minimum_version 1.5.0

setup() {
  source "$PWD/lib/shared.bash"
  export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR=true
  export -f record_capture
}

# Records every argument of a capture-error call.
function record_capture {
  [[ "$1" == job && "$2" == capture-error ]] || return 1
  local arg
  for arg in "${@:3}"; do
    jq -n --arg arg "$arg" '$arg'
  done | jq -sc '{args: .}' >>"$payload_file"
}

# Asserts that one error was captured with exactly this code and message, and
# no other arguments.
function assert_captured {
  local code="$1" message="$2"
  cat "$payload_file"
  [[ "$(wc -l <"$payload_file")" -eq 1 ]]
  jq -e --arg code "$code" --arg message "$message" \
    '.args == [$code, "--message", $message]' "$payload_file" >/dev/null
}

function configure_docker_hook {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_JOB_ID=1-2-3-4
  export BUILDKITE_PLUGIN_DOCKER_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_RUN_LABELS=false
  export BUILDKITE_COMMAND=pwd
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
}

@test "successful Docker run after a pull retry emits no captured error" {
  configure_docker_hook
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES=2
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() { printf called >"$marker"; }
  export -f buildkite-agent
  stub docker \
    "pull image:tag : exit 40" \
    "pull image:tag : echo pulled image" \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume /tmp/job.sock:/tmp/job.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command"

  run "$PWD/hooks/command"

  assert_success
  assert_output --partial "ran command"
  [[ ! -e "$marker" ]]
  unstub docker
}

@test "failed Docker run captures the failure without changing status or output" {
  configure_docker_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    record_capture "$@"
    echo 'Unknown command: capture-error' >&2
    return 22
  }
  export -f buildkite-agent
  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume /tmp/job.sock:/tmp/job.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo command-stdout; echo cannot-execute >&2; exit 126"

  run "$PWD/hooks/command"

  assert_failure 126
  assert_captured docker_run_failed "Docker run failed"
  [[ "$(grep -c '^cannot-execute$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^command-stdout$' <<<"$output")" -eq 1 ]]
  [[ "$output" != *'Unknown command'* ]]
  ! grep -q cannot-execute "$payload_file"
  unstub docker
}

@test "Docker run failures do not infer a cause from the exit status" {
  configure_docker_hook
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent

  # A contained command can return Docker's documented failure statuses too.
  for exit_status in 125 126 127 23; do
    payload_file="$BATS_TEST_TMPDIR/payload-$exit_status"
    export BUILDKITE_COMMAND="exit $exit_status"
    stub docker \
      "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume /tmp/job.sock:/tmp/job.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'exit $exit_status' : /bin/sh -e -c 'exit $exit_status'"

    run "$PWD/hooks/command"

    assert_failure "$exit_status"
    assert_captured docker_run_failed "Docker run failed"
    unstub docker
  done
}

@test "failed Docker pull captures image failure without changing status" {
  configure_docker_hook
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES=2
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; return 22; }
  export -f buildkite-agent
  stub docker \
    "pull image:tag : echo pull-retrying >&2; exit 40" \
    "pull image:tag : echo pull-denied >&2; exit 41"

  run "$PWD/hooks/command"

  assert_failure 41
  assert_captured image_pull_failed "Failed to pull image: pull-denied"
  [[ "$(grep -c '^pull-retrying$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^pull-denied$' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "Docker pull message uses Docker's error without stdout or terminal codes" {
  configure_docker_hook
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES=1
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent
  stub docker \
    "pull image:tag : printf '\\033[31mError response from daemon: manifest unknown\\033[0m   \\n' >&2; echo pull-progress; exit 1"

  run "$PWD/hooks/command"

  assert_failure 1
  assert_captured image_pull_failed "Failed to pull image: Error response from daemon: manifest unknown"
  [[ "$(grep -c '^pull-progress$' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "Docker pull without error output keeps the generic message" {
  configure_docker_hook
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES=1
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent
  stub docker \
    "pull image:tag : echo pull-progress; exit 1"

  run "$PWD/hooks/command"

  assert_failure 1
  assert_captured image_pull_failed "Failed to pull image"
  unstub docker
}

@test "Docker run failures do not include output in the message" {
  configure_docker_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  export -f buildkite-agent
  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume /tmp/job.sock:/tmp/job.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo workload-error >&2; exit 3"

  run "$PWD/hooks/command"

  assert_failure 3
  assert_captured docker_run_failed "Docker run failed"
  unstub docker
}

@test "stderr error line is the last line without terminal codes or surrounding whitespace" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf 'earlier line\r\n\033[1;33m \t Error: "quoted"  failure\033[0m \t\r\n\n\t\n  \n' >"$stderr_file"

  run stderr_error_line "$stderr_file" 100

  assert_success
  # Spaces inside the line are kept so redaction still matches secrets.
  assert_output 'Error: "quoted"  failure'
}

@test "stderr error line removes title and character set escape sequences" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf '\033]0;title\007\033(BError\033]8;;https://example.invalid\033\\: denied\n' >"$stderr_file"

  run stderr_error_line "$stderr_file" 100

  assert_success
  assert_output 'Error: denied'
}

@test "stderr error line is omitted rather than cut when it is too long" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf 'short\n0123456789\n' >"$stderr_file"

  run stderr_error_line "$stderr_file" 9

  assert_success
  assert_output ''

  run stderr_error_line "$stderr_file" 10

  assert_success
  assert_output '0123456789'
}

@test "stderr error line counts HTML characters as JSON escapes" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf 'a>&b\n' >"$stderr_file"

  # "a>&b" is 14 bytes once escaped: 2 plain characters plus 2 six-byte escapes.
  run stderr_error_line "$stderr_file" 13

  assert_success
  assert_output ''

  run stderr_error_line "$stderr_file" 14

  assert_success
  assert_output 'a>&b'
}

@test "stderr error line is empty for empty stderr" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  : >"$stderr_file"

  run stderr_error_line "$stderr_file" 100

  assert_success
  assert_output ''
}

@test "captured message keeps the generic message when the error line is too long" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  printf '%01100d\n' 0 >"$stderr_file"

  run capture_docker_error image_pull_failed "Failed to pull image" "$stderr_file"

  assert_success
  assert_captured image_pull_failed "Failed to pull image"
}

@test "run_copying_stderr preserves output streams and exit status" {
  stderr_file="$BATS_TEST_TMPDIR/stderr"
  function noisy() { echo out; echo err >&2; return 7; }

  run --separate-stderr run_copying_stderr "$stderr_file" noisy

  assert_failure 7
  [[ "$output" == out ]]
  [[ "$stderr" == err ]]
  [[ "$(cat "$stderr_file")" == err ]]
}

@test "capture reporting failure is ignored" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() { printf called >"$marker"; return 19; }

  run capture_docker_error image_pull_failed diagnostic

  assert_success
  [[ "$(cat "$marker")" == "called" ]]
}

@test "capture sends only a code and a message" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { record_capture "$@"; }

  run capture_docker_error docker_run_failed 'Docker run failed'

  assert_success
  assert_captured docker_run_failed 'Docker run failed'
}

@test "capture is skipped unless the agent advertises support" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  function buildkite-agent() { printf called >"$marker"; }
  for capability in unset false; do
    export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR="$capability"
    if [[ "$capability" == unset ]]; then
      unset BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR
    fi

    run capture_docker_error image_pull_failed diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}

@test "capture is skipped when the Local Job API is unavailable" {
  marker="$BATS_TEST_TMPDIR/called"
  function buildkite-agent() { printf called >"$marker"; return 99; }
  for missing in BUILDKITE_AGENT_JOB_API_SOCKET BUILDKITE_AGENT_JOB_API_TOKEN; do
    export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
    export BUILDKITE_AGENT_JOB_API_TOKEN=token
    unset "$missing"

    run capture_docker_error image_pull_failed diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}
