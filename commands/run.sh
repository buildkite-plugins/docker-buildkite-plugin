#!/bin/bash

set -euo pipefail

DIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

# shellcheck source=lib/shared.bash
. "$DIR/../lib/shared.bash"

tty_default='on'
interactive_default='on'
init_default='on'
mount_agent_default='off'
pwd_default="$PWD"
workdir_default="/workdir"
agent_mount_folder="/usr/bin/buildkite-agent"

# Set operating system specific defaults
if is_windows ; then
  tty_default=''
  init_default=''
  workdir_default="C:\\workdir"
  # escaping /C is a necessary workaround for an issue with Git for Windows 2.24.1.2
  # https://github.com/git-for-windows/git/issues/2442
  pwd_default="$(cmd.exe //C "echo %CD%")"

  # single quotes are important to avoid double-escaping the already escaped backslash
  agent_mount_folder='C:\\buildkite-agent'
fi


args=()

# Support switching tty off
if [[ "${BUILDKITE_PLUGIN_DOCKER_TTY:-$tty_default}" =~ ^(true|on|1)$ ]] ; then
  args+=("-t")
fi

# Support switching interactive off
if [[ "${BUILDKITE_PLUGIN_DOCKER_INTERACTIVE:-$interactive_default}" =~ ^(true|on|1)$ ]] ; then
  args+=("-i")
fi

if [[ ! "${BUILDKITE_PLUGIN_DOCKER_LEAVE_CONTAINER:-off}" =~ ^(true|on|1)$ ]] ; then
  args+=("--rm")
fi

# Support docker run --init.
if [[ "${BUILDKITE_PLUGIN_DOCKER_INIT:-$init_default}" =~ ^(true|on|1)$ ]] ; then
    args+=("--init")
fi

# Parse tmpfs property.
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_TMPFS ; then
  for arg in "${result[@]}" ; do
    args+=( "--tmpfs" "$(expand_relative_volume_path "${arg}")" )
  done
fi

workdir=''

if [[ -n "${BUILDKITE_PLUGIN_DOCKER_WORKDIR:-}" ]] || [[ "${BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT:-on}" =~ ^(true|on|1)$ ]] ; then
  workdir="${BUILDKITE_PLUGIN_DOCKER_WORKDIR:-$workdir_default}"
fi

# By default, mount $PWD onto $WORKDIR
if [[ "${BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT:-on}" =~ ^(true|on|1)$ ]] ; then
  args+=( "--volume" "${pwd_default}:${workdir}" )
fi

# Parse volumes (and deprecated mounts) and add them to the docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_VOLUMES BUILDKITE_PLUGIN_DOCKER_MOUNTS ; then
  for arg in "${result[@]}" ; do
    args+=( "--volume" "$(expand_relative_volume_path "${arg}")" )
  done
fi

# If there's a git mirror, mount it so that git references can be followed.
# But not if mount-checkout is disabled.
if [[ -n "${BUILDKITE_REPO_MIRROR:-}" && "${BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT:-on}" =~ ^(true|on|1)$ ]]; then
  args+=( "--volume" "$BUILDKITE_REPO_MIRROR:$BUILDKITE_REPO_MIRROR:ro" )
fi

# Parse devices and add them to the docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DEVICES ; then
  for arg in "${result[@]}" ; do
    args+=( "--device" "${arg}" )
  done
fi

# Parse sysctl args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_SYSCTLS ; then
  for arg in "${result[@]}" ; do
    args+=( "--sysctl" "$arg" )
  done
fi

# Parse cap-add args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_ADD_CAPS ; then
  for arg in "${result[@]}"; do
    args+=("--cap-add" "$arg")
  done
fi

# Parse cap-drop args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DROP_CAPS ; then
  for arg in "${result[@]}"; do
    args+=("--cap-drop" "$arg")
  done
fi

# Parse security-opts args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_SECURITY_OPTS ; then
  for arg in "${result[@]}"; do
    args+=("--security-opt" "$arg")
  done
fi

# Parse ulimits args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_ULIMITS ; then
  for arg in "${result[@]}"; do
    args+=("--ulimit" "$arg")
  done
fi

# Set workdir if one is provided or if the checkout is mounted
if [[ -n "${workdir:-}" ]] || [[ "${BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT:-on}" =~ ^(true|on|1)$ ]]; then
  args+=("--workdir" "${workdir}")
fi

# Support docker run --user
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_USER:-}" ]] && [[ -n "${BUILDKITE_PLUGIN_DOCKER_PROPAGATE_UID_GID:-}" ]]; then
  echo "+++ Error: Can't set both user and propagate-uid-gid"
  exit 1
fi

if [[ -n "${BUILDKITE_PLUGIN_DOCKER_USER:-}" ]] ; then
  args+=("-u" "${BUILDKITE_PLUGIN_DOCKER_USER:-}")
fi

# Parse publish args and add them to docker args
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_PUBLISH ; then
  for arg in "${result[@]}" ; do
    args+=( "--publish" "$arg" )
  done
fi

if [[ -n "${BUILDKITE_PLUGIN_DOCKER_PROPAGATE_UID_GID:-}" ]] ; then
  args+=("-u" "$(id -u):$(id -g)")
fi

# Support docker run --group-add
while IFS='=' read -r name _ ; do
  if [[ $name =~ ^(BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_[0-9]+) ]] ; then
    args+=( "--group-add" "${!name}" )
  fi
done < <(env | sort)

# Support docker run --userns
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_USERNS:-}" ]]; then
  # However, if BUILDKITE_PLUGIN_DOCKER_PRIVILEGED is enabled, then userns MUST
  # be overridden to host per limitations of docker
  # https://docs.docker.com/engine/security/userns-remap/#user-namespace-known-limitations
  if [[ "${BUILDKITE_PLUGIN_DOCKER_PRIVILEGED:-false}" =~ ^(true|on|1)$ ]] ; then
      args+=("--userns" "host")
  else
      args+=("--userns" "${BUILDKITE_PLUGIN_DOCKER_USERNS:-}")
  fi
fi

# Mount ssh-agent socket and known_hosts
if [[ ! "${BUILDKITE_PLUGIN_DOCKER_MOUNT_SSH_AGENT:-false}" = 'false' ]] ; then
  if [[ -z "${SSH_AUTH_SOCK:-}" ]] ; then
    echo "+++ 🚨 \$SSH_AUTH_SOCK isn't set, has ssh-agent started?"
    exit 1
  fi
  if [[ ! -S "${SSH_AUTH_SOCK}" ]] ; then
    echo "+++ 🚨 There file at ${SSH_AUTH_SOCK} does not exist or is not a socket, has ssh-agent started?"
    exit 1
  fi

  if [[ "${BUILDKITE_PLUGIN_DOCKER_MOUNT_SSH_AGENT:-''}" =~ ^(true|on|1)$ ]]; then
    MOUNT_PATH=/root
  else
    MOUNT_PATH="${BUILDKITE_PLUGIN_DOCKER_MOUNT_SSH_AGENT}"
  fi

  args+=(
    "--env" "SSH_AUTH_SOCK=/ssh-agent"
    "--volume" "${SSH_AUTH_SOCK}:/ssh-agent"
    "--volume" "${HOME}/.ssh/known_hosts:${MOUNT_PATH}/.ssh/known_hosts"
  )
fi

# Handle the mount-buildkite-agent option
if [[ "${BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT:-$mount_agent_default}" =~ ^(true|on|1)$ ]] ; then
  if [[ -z "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
    if is_windows; then
      echo -n "+++ 🚨 You must specify the variable BUILDKITE_AGENT_BINARY_PATH to mount the agent in Windows"
      exit 1
    elif ! command -v buildkite-agent >/dev/null 2>&1 ; then
      echo -n "+++ 🚨 Failed to find buildkite-agent in PATH to mount into container, "
      echo "you can disable this behaviour with 'mount-buildkite-agent:false'"
    else
      BUILDKITE_AGENT_BINARY_PATH=$(command -v buildkite-agent)
    fi
  fi
fi

# Mount buildkite-agent if we have a path for it
if [[ -n "${BUILDKITE_AGENT_BINARY_PATH:-}" ]] ; then
  args+=(
    "--env" "BUILDKITE_JOB_ID"
    "--env" "BUILDKITE_BUILD_ID"
    "--env" "BUILDKITE_AGENT_ACCESS_TOKEN"
    "--volume" "$BUILDKITE_AGENT_BINARY_PATH:${agent_mount_folder}"
  )
fi

# Parse extra env vars and add them to the docker args
while IFS='=' read -r name _ ; do
  if [[ $name =~ ^(BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_[0-9]+) ]] ; then
    args+=( "--env" "${!name}" )
  fi
done < <(env | sort)

# Parse host mappings and add them to the docker args
while IFS='=' read -r name _ ; do
  if [[ $name =~ ^(BUILDKITE_PLUGIN_DOCKER_ADD_HOST_[0-9]+) ]] ; then
    args+=( "--add-host" "${!name}" )
  fi
done < <(env | sort)

# Privileged container
if [[ "${BUILDKITE_PLUGIN_DOCKER_PRIVILEGED:-false}" =~ ^(true|on|1)$ ]] ; then
    args+=( "--privileged" )
fi

if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_ENV_FILE; then
  for arg in "${result[@]}"; do
    args+=("--env-file" "$arg")
  done
fi

# If requested, propagate a set of env vars as listed in a given env var to the
# container.
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST:-}" ]]; then
  if [[ -z "${!BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST:-}" ]]; then
    echo -n "env-propagation-list desired, but ${BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST} is not defined!"
    exit 1
  fi
  for var in ${!BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST}; do
    args+=("--env" "$var")
  done
fi

# Propagate all environment variables into the container if requested
if [[ "${BUILDKITE_PLUGIN_DOCKER_PROPAGATE_ENVIRONMENT:-false}" =~ ^(true|on|1)$ ]] ; then
  if [[ -n "${BUILDKITE_ENV_FILE:-}" ]] ; then
    # Read in the env file and convert to --env params for docker
    # This is because --env-file doesn't support newlines or quotes per https://docs.docker.com/compose/env-file/#syntax-rules
    while read -r var; do
      args+=( --env "${var%%=*}" )
    done < "$BUILDKITE_ENV_FILE"
  else
    echo -n "🚨 Not propagating environment variables to container as \$BUILDKITE_ENV_FILE is not set"
  fi
fi

# Propagate aws auth environment variables into the container e.g. from assume role plugins
if [[ "${BUILDKITE_PLUGIN_DOCKER_PROPAGATE_AWS_AUTH_TOKENS:-false}" =~ ^(true|on|1)$ ]] ; then
  if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] ; then
      args+=( --env "AWS_ACCESS_KEY_ID" )
  fi
  if [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]] ; then
      args+=( --env "AWS_SECRET_ACCESS_KEY" )
  fi
  if [[ -n "${AWS_SESSION_TOKEN:-}" ]] ; then
      args+=( --env "AWS_SESSION_TOKEN" )
  fi
  if [[ -n "${AWS_REGION:-}" ]] ; then
      args+=( --env "AWS_REGION" )
  fi
  if [[ -n "${AWS_DEFAULT_REGION:-}" ]] ; then
      args+=( --env "AWS_DEFAULT_REGION" )
  fi
  if [[ -n "${AWS_ROLE_ARN:-}" ]] ; then
      args+=( --env "AWS_ROLE_ARN" )
  fi
  if [[ -n "${AWS_STS_REGIONAL_ENDPOINTS:-}" ]] ; then
      args+=( --env "AWS_STS_REGIONAL_ENDPOINTS" )
  fi
  # Pass ECS variables when the agent is running in ECS
  # https://docs.aws.amazon.com/sdkref/latest/guide/feature-container-credentials.html
  if [[ -n "${AWS_CONTAINER_CREDENTIALS_FULL_URI:-}" ]] ; then
      args+=( --env "AWS_CONTAINER_CREDENTIALS_FULL_URI" )
  fi
  if [[ -n "${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI:-}" ]] ; then
      args+=( --env "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" )
  fi
  if [[ -n "${AWS_CONTAINER_AUTHORIZATION_TOKEN:-}" ]] ; then
      args+=( --env "AWS_CONTAINER_AUTHORIZATION_TOKEN" )
  fi
  # Pass EKS variables when the agent is running in EKS
  # https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts-minimum-sdk.html
  if [[ -n "${AWS_WEB_IDENTITY_TOKEN_FILE:-}" ]] ; then
      args+=( --env "AWS_WEB_IDENTITY_TOKEN_FILE" )
      # Add the token file as a volume
      args+=( --volume "${AWS_WEB_IDENTITY_TOKEN_FILE}:${AWS_WEB_IDENTITY_TOKEN_FILE}" )
  fi
fi

if [[ "${BUILDKITE_PLUGIN_DOCKER_EXPAND_IMAGE_VARS:-false}" =~ ^(true|on|1)$ ]] ; then
  image=$(eval echo "${BUILDKITE_PLUGIN_DOCKER_IMAGE}")
else
  image="${BUILDKITE_PLUGIN_DOCKER_IMAGE}"
fi

if [[ "${BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL:-false}" =~ ^(true|on|1)$ ]] ; then
  echo "--- :docker: Pulling ${image}"
  if ! retry "${BUILDKITE_PLUGIN_DOCKER_PULL_RETRIES:-3}" \
       docker pull "${image}" ; then
    retry_exit_status="$?"
    echo "!!! :docker: Pull failed."
    exit "$retry_exit_status"
  fi
fi

# Parse network and create it if it don't exist.
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_NETWORK:-}" ]] ; then
  DOCKER_NETWORK_ID=$(docker network ls --quiet --filter "name=${BUILDKITE_PLUGIN_DOCKER_NETWORK}")
  if [[ -z ${DOCKER_NETWORK_ID} ]] ; then
    echo "creating network ${BUILDKITE_PLUGIN_DOCKER_NETWORK}"
    docker network create "${BUILDKITE_PLUGIN_DOCKER_NETWORK}"
  else
    echo "docker network ${BUILDKITE_PLUGIN_DOCKER_NETWORK} already exists"
  fi
  args+=("--network" "${BUILDKITE_PLUGIN_DOCKER_NETWORK:-}")
fi

# Support docker run --platform
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_PLATFORM:-}" ]] ; then
  args+=("--platform" "${BUILDKITE_PLUGIN_DOCKER_PLATFORM:-}")
fi

# Support docker run --pid
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_PID:-}" ]] ; then
  args+=("--pid" "${BUILDKITE_PLUGIN_DOCKER_PID:-}")
fi

# Support docker run --gpus
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_GPUS:-}" ]] ; then
  args+=("--gpus" "${BUILDKITE_PLUGIN_DOCKER_GPUS:-}")
fi

# Support docker run --runtime
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_RUNTIME:-}" ]] ; then
  args+=("--runtime" "${BUILDKITE_PLUGIN_DOCKER_RUNTIME:-}")
fi

# Support docker run --ipc
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_IPC:-}" ]] ; then
  args+=("--ipc" "${BUILDKITE_PLUGIN_DOCKER_IPC:-}")
fi

# Support docker run --storage-opt
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_STORAGE_OPT:-}" ]] ; then
  args+=("--storage-opt" "${BUILDKITE_PLUGIN_DOCKER_STORAGE_OPT:-}")
fi

shell=()
shell_disabled=1

if [[ -n "${BUILDKITE_COMMAND}" ]]; then
  if [[ $(echo "$BUILDKITE_COMMAND" | wc -l) -gt 1 ]]; then
    # An array of commands in the step will be a single string with multiple lines
    # This breaks a lot of things here so we will print a warning for user to be aware
    echo "⚠️  Warning: The command received has multiple lines."
    echo "⚠️           The Docker Plugin may not correctly run multiple commands in the step-level configuration."
    echo "⚠️           You will need to use a single command, a script or the plugin's command option."
  fi
  shell_disabled=''
fi

# Handle setting of shm size if provided
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_SHM_SIZE:-}" ]]; then
  args+=("--shm-size" "${BUILDKITE_PLUGIN_DOCKER_SHM_SIZE}")
fi

# Handle setting of cpus if provided
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_CPUS:-}" ]]; then
  args+=("--cpus=${BUILDKITE_PLUGIN_DOCKER_CPUS}")
fi

# Handle memory limit if provided
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_MEMORY:-}" ]]; then
  args+=("--memory=${BUILDKITE_PLUGIN_DOCKER_MEMORY}")
fi

# Handle memory swap limit if provided
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAP:-}" ]]; then
  args+=("--memory-swap=${BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAP}")
fi

# Handle memory swappiness if provided
if [[ -n "${BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAPPINESS:-}" ]]; then
  args+=("--memory-swappiness=${BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAPPINESS}")
fi

# Handle setting device read throughput if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DEVICE_READ_BPS; then
  for arg in "${result[@]}"; do
    args+=("--device-read-bps" "$arg")
  done
fi

# Handle setting device write throughput if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DEVICE_WRITE_BPS; then
  for arg in "${result[@]}"; do
    args+=("--device-write-bps" "$arg")
  done
fi

# Handle setting device read IOPS if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DEVICE_READ_IOPS; then
  for arg in "${result[@]}"; do
    args+=("--device-read-iops" "$arg")
  done
fi

# Handle setting device write IOPS if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_DEVICE_WRITE_IOPS; then
  for arg in "${result[@]}"; do
    args+=("--device-write-iops" "$arg")
  done
fi

# Handle entrypoint if set, and default shell to disabled
if [[ -n ${BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT+x} ]]; then
  args+=("--entrypoint" "${BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT}")
  shell_disabled=1
fi

# Handle shell being disabled
if [[ "${BUILDKITE_PLUGIN_DOCKER_SHELL:-}" =~ ^(false|off|0)$ ]] ; then
  shell_disabled=1

# Show a helpful error message if a string version of shell is used
elif [[ -n "${BUILDKITE_PLUGIN_DOCKER_SHELL:-}" ]] ; then
  echo -n "🚨 The Docker Plugin’s shell configuration option can no longer be specified as a string, "
  echo -n "but only as an array. Please update your pipeline.yml to use an array, "
  echo "for example: [\"/bin/sh\", \"-e\", \"-u\"]."
  echo
  echo -n "Note that the docker plugin will infer a shell if one is required, so you might be able to remove"
  echo "the option entirely"
  exit 1

# Handle shell being provided as a string or list
elif plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_SHELL ; then
  shell_disabled=''
  for arg in "${result[@]}" ; do
    shell+=("$arg")
  done
fi

# Add the job id as meta-data for reference in pre-exit
args+=("--label" "com.buildkite.job-id=${BUILDKITE_JOB_ID}")  # Keep the kebab-case one for backwards compat

# Add useful labels to run container
if [[ "${BUILDKITE_PLUGIN_DOCKER_RUN_LABELS:-true}" =~ ^(true|on|1)$ ]] ; then
  args+=(
    "--label" "com.buildkite.pipeline_name=${BUILDKITE_PIPELINE_NAME}"
    "--label" "com.buildkite.pipeline_slug=${BUILDKITE_PIPELINE_SLUG}"
    "--label" "com.buildkite.build_number=${BUILDKITE_BUILD_NUMBER}"
    "--label" "com.buildkite.job_id=${BUILDKITE_JOB_ID}"
    "--label" "com.buildkite.job_label=${BUILDKITE_LABEL}"
    "--label" "com.buildkite.step_key=${BUILDKITE_STEP_KEY}"
    "--label" "com.buildkite.agent_name=${BUILDKITE_AGENT_NAME}"
    "--label" "com.buildkite.agent_id=${BUILDKITE_AGENT_ID}"
  )
fi

# Add the image in before the shell and command
args+=("${image}")

# Set a default shell if one is needed
if [[ -z $shell_disabled ]] && [[ ${#shell[@]} -eq 0 ]] ; then
  if is_windows ; then
    shell=("CMD.EXE" "/c")
  else
    shell=("/bin/sh" "-e" "-c")
  fi
fi

command=()

# Parse plugin command if provided
if plugin_read_list_into_result BUILDKITE_PLUGIN_DOCKER_COMMAND ; then
  for arg in "${result[@]}" ; do
    command+=("$arg")
  done
fi

if [[ ${#command[@]} -gt 0 ]] && [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  echo "+++ Error: Can't use both a step level command and the command parameter of the plugin"
  exit 1
fi

# Assemble the shell and command arguments into the docker arguments

if [[ ${#shell[@]} -gt 0 ]] ; then
  for shell_arg in "${shell[@]}" ; do
    args+=("$shell_arg")
  done
fi

if [[ -n "${BUILDKITE_COMMAND}" ]] ; then
  if is_windows ; then
    # The windows CMD shell only supports multiple commands with &&.
    windows_multi_command=${BUILDKITE_COMMAND//$'\n'/ && }
    args+=("${windows_multi_command}")
  else
    args+=("${BUILDKITE_COMMAND}")
  fi
elif [[ ${#command[@]} -gt 0 ]] ; then
  for command_arg in "${command[@]}" ; do
    args+=("$command_arg")
  done
fi

echo "--- :docker: Running command in ${image}"
echo -ne '\033[90m$\033[0m docker run ' >&2

# Print all the arguments, with a space after, properly shell quoted
printf "%q " "${args[@]}"
echo

# Disable -e outside of the subshell; since the subshell returning a failure
# would exit the parent shell (here) early.
set +e

# Don't convert paths on gitbash on windows, as that can mangle user paths and cmd options.
# See https://github.com/buildkite-plugins/docker-buildkite-plugin/issues/81 for more information.
( if is_windows ; then export MSYS_NO_PATHCONV=1; fi && docker run "${args[@]}" )

exit_code=$?

set -e

exit $exit_code  # propagate exit code
