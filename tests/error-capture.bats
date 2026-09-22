#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

setup() {
  source "$PWD/lib/shared.bash"
  export BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR=true
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

@test "Docker run exit statuses have customer-facing classifications" {
  [[ "$(docker_run_error_code 125)" == "container_runtime_failed" ]]
  [[ "$(docker_run_error_code 126)" == "container_command_not_executable" ]]
  [[ "$(docker_run_error_code 127)" == "container_command_not_found" ]]
  [[ "$(docker_run_error_code 23)" == "container_process_failed" ]]
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

@test "failed Docker run captures classification without changing status" {
  configure_docker_hook
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() {
    printf '%s' "$3" >"$payload_file"
    echo 'Unknown command: capture-error' >&2
    return 22
  }
  export -f buildkite-agent
  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume /tmp/job.sock:/tmp/job.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo command-stdout; echo cannot-execute >&2; exit 126"

  run "$PWD/hooks/command"

  assert_failure 126
  [[ "$(jq -r '.code' "$payload_file")" == "container_command_not_executable" ]]
  [[ "$(jq -r '.message' "$payload_file")" == "Container command failed" ]]
  [[ "$(grep -c '^cannot-execute$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^command-stdout$' <<<"$output")" -eq 1 ]]
  [[ "$output" != *'Unknown command'* ]]
  ! grep -q cannot-execute "$payload_file"
  unstub docker
}

@test "failed Docker pull captures image failure without changing status" {
  configure_docker_hook
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES=2
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { printf '%s\n' "$3" >>"$payload_file"; return 22; }
  export -f buildkite-agent
  stub docker \
    "pull image:tag : echo pull-retrying >&2; exit 40" \
    "pull image:tag : echo pull-denied >&2; exit 41"

  run "$PWD/hooks/command"

  assert_failure 41
  [[ "$(jq -r '.code' "$payload_file")" == "image_pull_failed" ]]
  [[ "$(wc -l <"$payload_file")" -eq 1 ]]
  [[ "$(grep -c '^pull-retrying$' <<<"$output")" -eq 1 ]]
  [[ "$(grep -c '^pull-denied$' <<<"$output")" -eq 1 ]]
  unstub docker
}

@test "capture reporting failure is ignored" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  marker="$BATS_TEST_TMPDIR/called"
  export marker
  function buildkite-agent() { printf called >"$marker"; return 19; }

  run capture_docker_error image_pull_failed pull 42 image:tag diagnostic

  assert_success
  [[ "$(cat "$marker")" == "called" ]]
}

@test "capture sends structured context without command arguments" {
  export BUILDKITE_AGENT_JOB_API_SOCKET=/tmp/job.sock
  export BUILDKITE_AGENT_JOB_API_TOKEN=token
  payload_file="$BATS_TEST_TMPDIR/payload"
  export payload_file
  function buildkite-agent() { printf '%s' "$3" >"$payload_file"; }

  run capture_docker_error container_command_not_found run 127 registry/image:tag 'executable "tool" not found'

  assert_success
  [[ "$(jq -r '.code' "$payload_file")" == "container_command_not_found" ]]
  [[ "$(jq -r '.context.exit_status' "$payload_file")" == "127" ]]
  [[ "$(jq -r '.context.image' "$payload_file")" == "registry/image:tag" ]]
  [[ "$(jq -r '.message' "$payload_file")" == 'executable "tool" not found' ]]
  [[ "$(jq -r 'has("command") or (.context | has("command"))' "$payload_file")" == "false" ]]
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

    run capture_docker_error image_pull_failed pull 42 image:tag diagnostic

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

    run capture_docker_error image_pull_failed pull 42 image:tag diagnostic

    assert_success
    [[ ! -e "$marker" ]]
  done
}
