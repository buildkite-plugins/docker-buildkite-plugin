#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# Uncomment to enable stub debug output:
# export DOCKER_STUB_DEBUG=/dev/tty

@test "Run with BUILDKITE_COMMAND" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_COMMAND='command1 "a string"'
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent image:tag /bin/sh -e -c 'command1 \"a string\"' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
}

@test "Pull image first before running BUILDKITE_COMMAND with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "pull image:tag : echo pulled latest image" \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled latest image"
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
}

@test "Runs BUILDKITE_COMMAND with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
}

@test "Runs BUILDKITE_COMMAND with volumes" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0=.:/app
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_1=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1
}

@test "Runs BUILDKITE_COMMAND with deprecated mounts" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNTS_0=.:/app
  export BUILDKITE_PLUGIN_DOCKER_MOUNTS_1=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1
}

@test "Runs BUILDKITE_COMMAND with environment" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=ANOTHER_TAG=llamas
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --env MY_TAG=value --env ANOTHER_TAG=llamas image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0
  unset BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1
}

@test "Runs BUILDKITE_COMMAND with user" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_USER=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir -u foo image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_USER
}

@test "Runs BUILDKITE_COMMAND with additional groups" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0=foo
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1=bar
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --group-add foo --group-add bar image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0
  unset BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1
}

@test "Runs BUILDKITE_COMMAND with network that doesn't exist" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_NETWORK=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "network ls --quiet --filter 'name=foo' : echo " \
    "network create foo : echo creating network foo" \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --network foo image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "creating network foo"
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_COMMAND
  unset BUILDKITE_PLUGIN_DOCKER_NETWORK
}

@test "Runs BUILDKITE_COMMAND with debug mode" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_DEBUG=true
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "Enabling debug mode"
  assert_output --partial "$ docker run"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_DEBUG
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with custom runtime" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_RUNTIME=custom_runtime
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --runtime custom_runtime image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_RUNTIME
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with entrypoint without explicit shell" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=/some/custom/entry/point
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with entrypoint with explicit shell" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=/some/custom/entry/point
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with shell" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with shell option as string" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_SHELL='custom-bash -a -b'
  export BUILDKITE_COMMAND="echo hello world"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "shell configuration option can no longer be specified as a string, but only as an array"

  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs BUILDKITE_COMMAND with shell disabled" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_SHELL=false
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs with a command as a string" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_COMMAND="echo hello world"
  export BUILDKITE_COMMAND=

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "command configuration option must be an array"

  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs with a command as an array" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs with a command as an array with a shell" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}

@test "Runs with a command as an array with a shell and an entrypoint" {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT='llamas.sh'
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --volume $PWD:/workdir --workdir /workdir --entrypoint llamas.sh image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unset BUILDKITE_PLUGIN_DOCKER_IMAGE
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_SHELL
  unset BUILDKITE_COMMAND
}
