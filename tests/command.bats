#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

# Uncomment to enable stub debug output:
# export DOCKER_STUB_DEBUG=/dev/tty

setup() {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_JOB_ID="1-2-3-4"
  export BUILDKITE_PLUGIN_DOCKER_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"
}

@test "Run with BUILDKITE_COMMAND" {
  export BUILDKITE_COMMAND='command1 "a string"'
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'command1 \"a string\"' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Run with BUILDKITE_COMMAND and cleanup remaining containers" {
  export BUILDKITE_COMMAND='command1 "a string"'
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT
  unset BUILDKITE_PLUGIN_DOCKER_CLEANUP

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'command1 \"a string\"' : echo ran command in docker" \
    "ps -a -q --filter label=com.buildkite.job-id=1-2-3-4 : echo 939fb4ab31b2" \
    "stop 939fb4ab31b2 : echo stopped container"

  run bash -c "$PWD/hooks/command && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "ran command in docker"
  assert_output --partial "stopped container"

  unstub docker
}

@test "Pull image first before running BUILDKITE_COMMAND with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true

  stub docker \
    "pull image:tag : echo pulled latest image" \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "pulled latest image"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-buildkite-agent disabled" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with volumes" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with devices" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_DEVICES_0=/dev/bus/usb/001/001
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --device /dev/bus/usb/001/001 --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with publish" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_PUBLISH_0=80:8080
  export BUILDKITE_PLUGIN_DOCKER_PUBLISH_1=90:9090
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --publish 80:8080 --publish 90:9090 --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with sysctls" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_SYSCTLS_0=net.ipv4.ip_forward=1
  export BUILDKITE_PLUGIN_DOCKER_SYSCTLS_1=net.unix.max_dgram_qlen=200
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --sysctl net.ipv4.ip_forward=1 --sysctl net.unix.max_dgram_qlen=200 --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-checkout=false" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT=false
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-checkout=true" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT=true
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with deprecated mounts" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_PLUGIN_DOCKER_MOUNTS_0=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -it --rm --init --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with environment" {
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=ANOTHER_TAG=llamas
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --env MY_TAG=value --env ANOTHER_TAG=llamas --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with shm size" {
  export BUILDKITE_PLUGIN_DOCKER_SHM_SIZE=100mb
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --shm-size 100mb --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with propagate environment" {
  export BUILDKITE_PLUGIN_DOCKER_PROPAGATE_ENVIRONMENT=true
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_ENV_FILE="/tmp/amazing"

  cat << EOF > $BUILDKITE_ENV_FILE
FOO="BAR"
A_VARIABLE="with\nnewline"
EOF

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --env MY_TAG=value --env FOO --env A_VARIABLE --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with user" {
  export BUILDKITE_PLUGIN_DOCKER_USER=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir -u foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with userns" {
  export BUILDKITE_PLUGIN_DOCKER_USERNS=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --userns foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with additional groups" {
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0=foo
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1=bar
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --group-add foo --group-add bar --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with propagated uid and guid" {
  export BUILDKITE_PLUGIN_DOCKER_PROPAGATE_UID_GID=true
  export BUILDKITE_COMMAND="echo hello world"

  stub id \
    "-u : echo 123" \
    "-g : echo 456"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir -u 123:456 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub id
  unstub docker
}

@test "Runs BUILDKITE_COMMAND with network that doesn't exist" {
  export BUILDKITE_PLUGIN_DOCKER_NETWORK=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "network ls --quiet --filter 'name=foo' : echo " \
    "network create foo : echo creating network foo" \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --network foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "creating network foo"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with custom runtime" {
  export BUILDKITE_PLUGIN_DOCKER_RUNTIME=custom_runtime
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --runtime custom_runtime --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint without explicit shell" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=/some/custom/entry/point
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint with explicit shell" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=/some/custom/entry/point
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint disabled by null" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=''
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint '\'\'' image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint disabled by false" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=false
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint '\'\'' image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with shell" {
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with shell option as string" {
  export BUILDKITE_PLUGIN_DOCKER_SHELL='custom-bash -a -b'
  export BUILDKITE_COMMAND="echo hello world"

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "shell configuration option can no longer be specified as a string, but only as an array"
}

@test "Runs BUILDKITE_COMMAND with shell disabled" {
  export BUILDKITE_PLUGIN_DOCKER_SHELL=false
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with add-host" {
  export BUILDKITE_PLUGIN_DOCKER_ADD_HOST_0=buildkite.fake:127.0.0.1
  export BUILDKITE_PLUGIN_DOCKER_ADD_HOST_1=www.buildkite.local:0.0.0.0
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --add-host buildkite.fake:127.0.0.1 --add-host www.buildkite.local:0.0.0.0 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs with a command as a string" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND="echo hello world"
  export BUILDKITE_COMMAND=

  run $PWD/hooks/command

  assert_failure
  assert_output --partial "🚨 Plugin received a string for BUILDKITE_PLUGIN_DOCKER_COMMAND, expected an array"
}

@test "Runs with a command as an array" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs with a command as an array with a shell" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs with a command as an array with a shell and an entrypoint" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_PLUGIN_DOCKER_SHELL_0='custom-bash'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_1='-a'
  export BUILDKITE_PLUGIN_DOCKER_SHELL_2='-b'
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT='llamas.sh'
  export BUILDKITE_COMMAND=

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint llamas.sh --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Doesn't disclose environment" {
  export BUILDKITE_COMMAND='echo hello world'
  export SUPER_SECRET=supersecret

  stub docker \
    "run -it --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run $PWD/hooks/command

  assert_success
  refute_output --partial "supersecret"

  unstub docker
}
