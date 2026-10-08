#!/bin/bash

set -euo pipefail

# retry <number-of-retries> <command>
function retry {
  local retries=$1; shift
  local attempts=1

  until "$@"; do
    local retry_exit_status=$?
    echo "Exited with $retry_exit_status"
    if (( retries == "0" )); then
      return $retry_exit_status
    elif (( attempts == retries )); then
      echo "Failed $attempts retries"
      return $retry_exit_status
    else
      echo "Retrying $((retries - attempts)) more times..."
      attempts=$((attempts + 1))
      sleep $(((attempts - 2) * 2))
    fi
  done
}

function json_escape {
  local value="$1"
  value="$(printf '%s' "$value" | LC_ALL=C tr -d '\000-\010\013\014\016-\037')"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\r'/\\r}
  value=${value//$'\n'/\\n}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

# Runs a command and also saves its stderr to a file. Output and exit status
# are unchanged. Without a file, the command runs normally.
function run_copying_stderr {
  local stderr_file="$1"; shift
  if [[ -z "$stderr_file" ]]; then
    "$@"
    return
  fi
  { "$@" 2>&1 1>&3 3>&- | tee "$stderr_file" >&2 3>&-; return "${PIPESTATUS[0]}"; } 3>&1
}

# Prints a temporary file path for a stderr copy, or nothing if error capture
# is unavailable or a file can't be created.
function capture_stderr_file {
  [[ "${BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR:-}" == "true" ]] || return 0
  [[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" && -n "${BUILDKITE_AGENT_JOB_API_TOKEN:-}" ]] || return 0
  mktemp 2>/dev/null || true
}

# Prints the last non-blank line of a stderr file, which is usually the error,
# without terminal escape codes. Prints nothing if the line is longer than
# max_chars, because cutting it could leave part of a secret that can no
# longer be redacted.
function stderr_error_line {
  local stderr_file="$1" max_chars="$2" line
  [[ -s "$stderr_file" ]] || return 0
  line=$(tr '\r' '\n' <"$stderr_file" \
    | sed -e $'s/\x1b\\[[0-?]*[ -/]*[@-~]//g' \
      -e $'s/\x1b][^\x07\x1b]*\x07//g' -e $'s/\x1b][^\x07\x1b]*\x1b\\\\//g' \
      -e $'s/\x1b[()][0-9A-Za-z]//g' \
      -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr -d '\000-\010\013-\037\177' \
    | grep -v '^$' \
    | tail -n 1) || true
  if (( $(printf '%s' "$line" | wc -m) <= max_chars )); then
    printf '%s' "$line"
  fi
}

# The agent accepts up to 1,000 characters. This leaves room for [REDACTED]
# replacements.
CAPTURED_ERROR_MESSAGE_MAX_CHARS=750

# Captures a job error. If stderr_file is given, Docker's error is added to
# the message. Reporting failures are ignored.
function capture_docker_error {
  local error_code="$1" message="$2" stderr_file="${3:-}" detail
  [[ "${BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR:-}" == "true" ]] || return 0
  [[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" && -n "${BUILDKITE_AGENT_JOB_API_TOKEN:-}" ]] || return 0

  if [[ -n "$stderr_file" ]]; then
    detail=$(stderr_error_line "$stderr_file" "$((CAPTURED_ERROR_MESSAGE_MAX_CHARS - ${#message} - 2))")
    if [[ -n "$detail" ]]; then
      message+=": $detail"
    fi
  fi
  buildkite-agent job capture-error "$error_code" --message "$message" >/dev/null 2>&1 || true
}

# Reads a list from plugin config into a global result array
# Returns success if values were read
function plugin_read_list_into_result() {
  result=()

  for prefix in "$@" ; do
    local i=0
    local parameter="${prefix}_${i}"

    if [[ -n "${!prefix:-}" ]] ; then
      echo "🚨 Plugin received a string for $prefix, expected an array" >&2
      exit 1
    fi

    while [[ -n "${!parameter:-}" ]]; do
      result+=("${!parameter}")
      i=$((i+1))
      parameter="${prefix}_${i}"
    done
  done

  [[ ${#result[@]} -gt 0 ]] || return 1
}

# docker's -v arguments don't do local path expansion, so we add very simple support for .
function expand_relative_volume_path() {
  local path

  if [[ "${BUILDKITE_PLUGIN_DOCKER_EXPAND_VOLUME_VARS:-false}" =~ ^(true|on|1)$ ]]; then
    path=$(eval echo "$1")
  else
    path="$1"
  fi

  if [[ $path =~ ^\.: ]] ; then
    printf "%s" "${PWD}${path#.}"
  elif [[ $path =~ ^\.(/|\\) ]] ; then
    printf "%s" "${PWD}/${path#.}"
  else
    echo "$path"
  fi
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
function is_windows() {
  [[ "$OSTYPE" =~ ^(win|msys|cygwin) ]]
}

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
function is_macos() {
  [[ "$OSTYPE" =~ ^(darwin) ]]
}
