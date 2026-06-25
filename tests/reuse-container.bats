#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

# Uncomment to enable stub debug output:
# export DOCKER_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_JOB_ID="1-2-3-4"
  export BUILDKITE_PLUGIN_DOCKER_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"
  export BUILDKITE_PLUGIN_DOCKER_RUN_LABELS="false"
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER=true
  export BUILDKITE_AGENT_NAME="builder-3"

  # Redirect the host tainted-marker scratch base away from the real /var/tmp so
  # tests never write outside their sandbox.
  TAINTED_BASE="$(mktemp -d)"
  export BUILDKITE_PLUGIN_DOCKER_REUSE_TAINTED_BASE="${TAINTED_BASE}"

  # The create-flag fingerprint the plugin will compute for the default config:
  # frozen flags in build order, joined with "," (per-exec flags -t/-i/--workdir,
  # the job-id --label, and the tainted mount are excluded). For this setup that
  # is "--init" plus the inode-annotated checkout volume.
  FP="--init,--volume=${PWD}:/workdir#$(ls -di "$PWD" | awk '{print $1}')"
}

teardown() {
  rm -rf "${TAINTED_BASE}"
  if [[ -n "${JOBAPI_DIR:-}" ]]; then
    rm -rf "${JOBAPI_DIR}"
  fi
}

@test "Reuse container: creates new container when none exists" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Creating persistent container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: exec into existing container with matching image digest and fingerprint" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Reusing existing container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: recreates container when create-flag fingerprint changes" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo some-old-fingerprint" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Create-flag fingerprint changed"
  assert_output --partial "Creating persistent container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: recreates container when fingerprint label is missing" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ''" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Create-flag fingerprint changed"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: recreates when a create-time flag (tmpfs) changes" {
  export BUILDKITE_PLUGIN_DOCKER_TMPFS_0="/home/zoox/.cache:mode=777"
  TMPFS_FP="--init,--tmpfs,/home/zoox/.cache:mode=777,--volume=${PWD}:/workdir#$(ls -di "$PWD" | awk '{print $1}')"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --tmpfs /home/zoox/.cache:mode=777 --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${TMPFS_FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Create-flag fingerprint changed"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: mounts the Job API socket directory (not the file) on create" {
  JOBAPI_DIR="$(mktemp -d)"
  export BUILDKITE_AGENT_JOB_API_SOCKET="${JOBAPI_DIR}/3760-27802.sock"
  export BUILDKITE_AGENT_JOB_API_TOKEN="tok"
  local jfp="--init,--volume=${PWD}:/workdir#$(ls -di "$PWD" | awk '{print $1}'),--volume=${JOBAPI_DIR}:${JOBAPI_DIR}#$(ls -di "$JOBAPI_DIR" | awk '{print $1}')"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --volume ${JOBAPI_DIR}:${JOBAPI_DIR} --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${jfp} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Creating persistent container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: reuses despite a changed Job API socket filename" {
  JOBAPI_DIR="$(mktemp -d)"
  # A later job's socket lives in the same dir under a different filename.
  export BUILDKITE_AGENT_JOB_API_SOCKET="${JOBAPI_DIR}/4178-50521.sock"
  export BUILDKITE_AGENT_JOB_API_TOKEN="tok2"
  # The stored fingerprint (from the job that created the container) keys off
  # the stable directory mount, so it matches this job's recomputed value.
  local jfp="--init,--volume=${PWD}:/workdir#$(ls -di "$PWD" | awk '{print $1}'),--volume=${JOBAPI_DIR}:${JOBAPI_DIR}#$(ls -di "$JOBAPI_DIR" | awk '{print $1}')"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${jfp}" \
    "exec -t -i --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Reusing existing container"
  refute_output --partial "fingerprint changed"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: non-reuse path mounts the single Job API socket file" {
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER=false
  JOBAPI_DIR="$(mktemp -d)"
  export BUILDKITE_AGENT_JOB_API_SOCKET="${JOBAPI_DIR}/3760-27802.sock"
  export BUILDKITE_AGENT_JOB_API_TOKEN="tok"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_AGENT_JOB_API_SOCKET --env BUILDKITE_AGENT_JOB_API_TOKEN --volume ${JOBAPI_DIR}/3760-27802.sock:${JOBAPI_DIR}/3760-27802.sock --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: discards tainted container and recreates" {
  mkdir -p "${TAINTED_BASE}/image-tag-3"
  echo "out of memory" > "${TAINTED_BASE}/image-tag-3/tainted"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "is tainted"
  assert_output --partial "reason: out of memory"
  assert_output --partial "ran command in docker"
  # The marker is cleared and the dir re-created (and writable) on recreation.
  [ ! -f "${TAINTED_BASE}/image-tag-3/tainted" ]
  [ -d "${TAINTED_BASE}/image-tag-3" ]

  unstub docker
}

@test "Reuse container: replaces container on image digest mismatch" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:olddigest" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:newdigest" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "WARNING: Container image mismatch"
  assert_output --partial "Expected image: image:tag (sha256:newdigest)"
  assert_output --partial "Container image ID: sha256:olddigest"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: removes and recreates stopped container" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo false" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Removing stopped container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: discards mismatched persistent container, keeps desired" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : printf '%s\n' image-other-3 image-tag-3" \
    "rm -f image-other-3 : echo removed" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Discarding persistent container image-other-3"
  assert_output --partial "Reusing existing container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: non-reuse job discards leftover persistent container" {
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER=false

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "rm -f image-tag-3 : echo removed" \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Discarding persistent container image-tag-3"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: uses custom container name" {
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER_NAME="my-custom-container"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "container inspect --format '{{.State.Running}}' my-custom-container : exit 1" \
    "run -d --name my-custom-container -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/my-custom-container:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir my-custom-container /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Creating persistent container my-custom-container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: rejects path-traversal custom container name" {
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER_NAME="../evil"

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Invalid reuse container name"

  unstub docker
}

@test "Reuse container: omits spawn index and cleanup when agent name has no numeric suffix" {
  export BUILDKITE_AGENT_NAME="solo-agent"

  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag : exit 1" \
    "run -d --name image-tag -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Warning: Could not extract numeric spawn index"
  assert_output --partial "Creating persistent container image-tag"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: passes environment variables to exec" {
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=OTHER=thing

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "exec -t -i --workdir /workdir --env MY_TAG=value --env OTHER=thing image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: env vars stripped from creation but passed to exec" {
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=SECRET=supersecret

  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir --env MY_TAG=value --env SECRET=supersecret image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: pre-exit skips cleanup" {
  export BUILDKITE_PLUGIN_DOCKER_CLEANUP=true

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial "Skipping container cleanup (reuse-container is enabled)"
}

@test "Reuse container: no --rm flag in docker run args" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo ''" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --label com.buildkite.docker-plugin.reuse=true --label com.buildkite.docker-plugin.spawn-slot=3 --label com.buildkite.docker-plugin.fingerprint=${FP} --volume ${TAINTED_BASE}/image-tag-3:/var/run/buildkite-docker-reuse --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial -- "--rm"

  unstub docker
}

@test "Reuse container: propagates exec exit code on failure" {
  stub docker \
    "ps -a --filter label=com.buildkite.docker-plugin.reuse=true --filter label=com.buildkite.docker-plugin.spawn-slot=3 --format '{{.Names}}' : echo image-tag-3" \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "inspect --format \* image-tag-3 : echo ${FP}" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : exit 42"

  run "$PWD"/hooks/command

  assert_failure 42

  unstub docker
}
