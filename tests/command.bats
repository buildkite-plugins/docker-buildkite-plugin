#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# Uncomment to enable stub debug output:
export DOCKER_STUB_DEBUG=/dev/tty
# export WHICH_STUB_DEBUG=/dev/tty

@test "Run command" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_COMMAND="command1 \"a string\" && command2"

  stub which \
    "buildkite-agent : echo /buildkite-agent"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --env BUILDKITE_JOB_ID  --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent image:tag bash -c 'command1 \"a string\" && command2' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unstub which
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
}

@test "Run command without a workdir should not fail" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_COMMAND="command1 \"a string\" && command2"

  stub which \
    "buildkite-agent : echo /buildkite-agent"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID  --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent image:tag bash -c 'command1 \"a string\" && command2' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unstub which
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
}

@test "Runs the command with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app image:tag bash -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
}


@test "Runs command with environment" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=ANOTHER_TAG=$'llamas\nalpacas'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --env MY_TAG=value --env ANOTHER_TAG=$'llamas\nalpacas' image:tag bash -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1
}
