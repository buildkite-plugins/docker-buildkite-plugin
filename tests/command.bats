#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# Uncomment to enable stub debug output:
# export DOCKER_STUB_DEBUG=/dev/tty

@test "Run command" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_COMMAND='command1 "a string"'
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --env BUILDKITE_JOB_ID  --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent image:tag bash -c 'command1 \"a string\"' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
}

@test "Run command without a workdir should not fail" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_COMMAND="command1 \"a string\""
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID  --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent image:tag bash -c 'command1 \"a string\"' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
}

@test "Pull image first before running the command with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "pull image:tag : echo pulled latest image" \
    "run -it --rm --volume $PWD:/app --workdir /app image:tag bash -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled latest image"
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
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

@test "Runs command with volumes" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNTS_0=/hello:/hello-world
  export BUILDKITE_PLUGIN_DOCKER_MOUNTS_1=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --volume /hello:/hello-world --volume /var/run/docker.sock:/var/run/docker.sock image:tag bash -c 'echo hello world; pwd' : echo ran command in docker"

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


@test "Runs command with environment" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=ANOTHER_TAG=llamas
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --env MY_TAG=value --env ANOTHER_TAG=llamas image:tag bash -c 'echo hello world' : echo ran command in docker"

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

@test "Runs command with user" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_USER=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app -u foo image:tag bash -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_USER
}

@test "Runs command with additional groups" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0=foo
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1=bar
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app --group-add foo --group-add bar image:tag bash -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0
  unset BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1
}

@test "Runs command with network that doesn't exist" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_NETWORK=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "network ls --quiet --filter 'name=foo' : echo " \
    "network create foo : echo creating network foo" \
    "run -it --rm --volume $PWD:/app --workdir /app --network foo image:tag bash -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "creating network foo"
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_NETWORK
}


@test "Runs with debug mode" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_DEBUG=true
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/app --workdir /app image:tag bash -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "Enabling debug mode"
  assert_output --partial "$ docker run"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_WORKDIR
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_DEBUG
  unset BUILDKITE_COMMAND
}
