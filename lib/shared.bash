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

# Returns the agent's numeric spawn index (the trailing "-N" of
# BUILDKITE_AGENT_NAME), or nothing if it cannot be determined. This is the
# per-slot key that scopes reuse containers and their cleanup to one agent on a
# shared host. Computed from BUILDKITE_AGENT_NAME directly so it stays correct
# even when an explicit reuse-container-name is used.
function get_spawn_slot() {
  local agent_name="${BUILDKITE_AGENT_NAME:-}"
  local spawn_suffix="${agent_name##*-}"
  if [[ "${spawn_suffix}" =~ ^[0-9]+$ ]]; then
    echo "${spawn_suffix}"
  fi
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

  local spawn_suffix
  spawn_suffix="$(get_spawn_slot)"
  if [[ -n "${spawn_suffix}" ]]; then
    name="${name}-${spawn_suffix}"
  else
    echo "Warning: Could not extract numeric spawn index from BUILDKITE_AGENT_NAME '${BUILDKITE_AGENT_NAME:-}'." >&2
    echo "  Multiple agents on the same host may share container name '${name}'." >&2
    echo "  Set 'reuse-container-name' to specify an explicit container name." >&2
  fi

  echo "${name}"
}

# Returns the inode number of a host path, portably across GNU and BSD/macOS
# (avoids the GNU-only `stat -c %i`). Prints "missing" when the path does not
# exist, which still yields a deterministic, comparable fingerprint entry.
function get_host_inode() {
  local path="$1"
  if [[ -e "${path}" ]]; then
    # `ls -d -i` prints "<inode> <path>" for the path itself (not contents).
    # shellcheck disable=SC2012  # `find -printf` is GNU-only; ls keeps this
    # portable to BSD/macOS, and we only read the leading inode field.
    ls -di "${path}" 2>/dev/null | awk '{print $1}'
  else
    echo "missing"
  fi
}

# Computes a deterministic fingerprint of the create-time flags a reuse
# container is (re)created with, so a later job can detect when it would reuse a
# container that was built with different flags (mismatch) or with a bind-mount
# source that has since been wiped and re-created on the host (staleness, e.g. a
# re-cloned checkout). This covers EVERY flag frozen at container creation
# (volumes, tmpfs, network, devices, caps, resources, etc.), so changing any of
# them forces a fresh container.
#
# Excluded (deliberately):
#   - flags re-applied on each `docker exec` and therefore allowed to differ
#     between jobs without a recreate: -t, -i, --env, --env-file, --workdir, -u;
#   - all --label values (volatile per-job metadata and the plugin's own labels);
#   - the plugin-internal tainted-marker --volume (identified by <tainted_target>).
# For each remaining bind-mount --volume the host source inode is appended
# (absolute source, Unix only) so a wiped/re-created source is detected.
#
# Flags are kept in their (deterministic) build order and joined with ",". The
# raw string is returned (not hashed) to avoid depending on sha256sum vs shasum.
#
# Usage: compute_reuse_fingerprint <tainted_target> <flag>...
function compute_reuse_fingerprint() {
  local tainted_target="$1"; shift
  local -a flags=("$@")
  local -a entries=()
  local i=0

  while [[ $i -lt ${#flags[@]} ]]; do
    local flag="${flags[$i]}"
    case "${flag}" in
      -t|-i)
        # Per-exec flag (no value); not frozen.
        ;;
      --workdir|-u|--env|--env-file|--label)
        # Per-exec or volatile; skip the flag and its value.
        i=$((i+1))
        ;;
      --volume)
        local spec="${flags[$((i+1))]}"
        i=$((i+1))
        local rest="${spec#*:}"
        local dst="${rest%%:*}"
        if [[ -n "${tainted_target}" && "${dst}" == "${tainted_target}" ]]; then
          : # plugin-internal tainted-marker mount; not part of user config
        else
          local src="${spec%%:*}"
          if [[ "${src}" == /* ]] && ! is_windows; then
            entries+=("--volume=${spec}#$(get_host_inode "${src}")")
          else
            entries+=("--volume=${spec}")
          fi
        fi
        ;;
      *)
        # Any other create-time flag (or a value token of one): keep verbatim,
        # in order, so it contributes to the fingerprint.
        entries+=("${flag}")
        ;;
    esac
    i=$((i+1))
  done

  if [[ ${#entries[@]} -gt 0 ]]; then
    local IFS=','
    echo "${entries[*]}"
  fi
}

# Removes persistent reuse containers belonging to this agent's spawn slot that
# this job does not need, freeing their memory. Scoped per slot via labels so it
# never touches another agent's container on a shared host.
#   <slot>  the agent spawn slot (from get_spawn_slot).
#   <keep>  the one container name to preserve (the desired reuse container for
#           this job); pass "" for non-reuse jobs to discard all slot containers.
function cleanup_foreign_reuse_containers() {
  local slot="$1" keep="$2"
  local names
  names="$(docker ps -a \
    --filter "label=com.buildkite.docker-plugin.reuse=true" \
    --filter "label=com.buildkite.docker-plugin.spawn-slot=${slot}" \
    --format '{{.Names}}' 2>/dev/null || true)"

  [[ -z "${names}" ]] && return 0

  local name
  while IFS= read -r name; do
    [[ -z "${name}" ]] && continue
    [[ -n "${keep}" && "${name}" == "${keep}" ]] && continue
    echo "--- :docker: Discarding persistent container ${name} (not needed by this job on slot ${slot})"
    docker rm -f "${name}" >/dev/null 2>&1 || true
  done <<< "${names}"
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

