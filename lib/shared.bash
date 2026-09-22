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

# Reporting is best-effort and preserves Docker's original exit status.
function capture_docker_error {
  local code="$1" operation="$2" exit_status="$3" image="$4" message="$5" payload
  [[ "${BUILDKITE_AGENT_JOB_API_CAPTURE_ERROR:-}" == "true" ]] || return 0
  [[ -n "${BUILDKITE_AGENT_JOB_API_SOCKET:-}" && -n "${BUILDKITE_AGENT_JOB_API_TOKEN:-}" ]] || return 0

  payload=$(printf '{"code":"%s","message":"%s","context":{"plugin":"docker","operation":"%s","image":"%s","exit_status":%d}}' \
    "$(json_escape "$code")" "$(json_escape "$message")" "$(json_escape "$operation")" \
    "$(json_escape "$image")" "$exit_status")
  buildkite-agent job capture-error "$payload" >/dev/null 2>&1 || true
}

function docker_run_error_code {
  case "$1" in
    125) echo "container_runtime_failed" ;;
    126) echo "container_command_not_executable" ;;
    127) echo "container_command_not_found" ;;
    *) echo "container_process_failed" ;;
  esac
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
