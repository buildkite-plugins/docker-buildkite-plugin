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

# Returns a stable container name for the reuse-container feature.
# Uses the explicit override if set, otherwise derives from the image name
# and the agent's spawn index (to isolate containers per agent on a host).
function get_reuse_container_name() {
  local image="$1"

  if [[ -n "${BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER_NAME:-}" ]]; then
    echo "${BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER_NAME}"
    return
  fi

  local sanitized="${image//[^a-zA-Z0-9_.-]/-}"
  local name="${sanitized}"

  local spawn_suffix="${BUILDKITE_AGENT_NAME##*-}"
  if [[ "${spawn_suffix}" =~ ^[0-9]+$ ]]; then
    name="${name}-${spawn_suffix}"
  else
    echo "Warning: Could not extract numeric spawn index from BUILDKITE_AGENT_NAME '${BUILDKITE_AGENT_NAME}'." >&2
    echo "  Multiple agents on the same host may share container name '${name}'." >&2
    echo "  Set 'reuse-container-name' to specify an explicit container name." >&2
  fi

  echo "${name}"
}

# Returns the image ID (digest) of the image a container was created from.
function get_container_image_id() {
  local container_name="$1"
  docker inspect --format '{{.Image}}' "${container_name}" 2>/dev/null
}

# Returns the image ID (digest) of a local image.
function get_image_id() {
  local image="$1"
  docker image inspect --format '{{.Id}}' "${image}" 2>/dev/null
}

