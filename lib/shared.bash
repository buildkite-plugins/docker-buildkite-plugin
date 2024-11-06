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

