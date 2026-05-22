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
}

@test "Reuse container: creates new container when none exists" {
  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Creating persistent container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: exec into existing container with matching image digest" {
  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Reusing existing container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: replaces container on image digest mismatch" {
  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:olddigest" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:newdigest" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
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
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo false" \
    "rm -f image-tag-3 : echo removed" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Removing stopped container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: uses custom container name" {
  export BUILDKITE_PLUGIN_DOCKER_REUSE_CONTAINER_NAME="my-custom-container"

  stub docker \
    "container inspect --format '{{.State.Running}}' my-custom-container : exit 1" \
    "run -d --name my-custom-container -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir my-custom-container /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Creating persistent container my-custom-container"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Reuse container: omits spawn index when agent name has no numeric suffix" {
  export BUILDKITE_AGENT_NAME="solo-agent"

  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag : exit 1" \
    "run -d --name image-tag -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
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
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
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
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
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
    "container inspect --format '{{.State.Running}}' image-tag-3 : exit 1" \
    "run -d --name image-tag-3 -t -i --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 --entrypoint '' image:tag sleep infinity : echo abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial -- "--rm"

  unstub docker
}

@test "Reuse container: propagates exec exit code on failure" {
  stub docker \
    "container inspect --format '{{.State.Running}}' image-tag-3 : echo true" \
    "inspect --format '{{.Image}}' image-tag-3 : echo sha256:abc123" \
    "image inspect --format '{{.Id}}' image:tag : echo sha256:abc123" \
    "exec -t -i --workdir /workdir image-tag-3 /bin/sh -e -c 'pwd' : exit 42"

  run "$PWD"/hooks/command

  assert_failure 42

  unstub docker
}
