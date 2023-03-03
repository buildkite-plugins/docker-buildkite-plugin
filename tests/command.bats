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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'command1 \"a string\"' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'command1 \"a string\"' : echo ran command in docker" \
    "ps -a -q --filter label=com.buildkite.job-id=1-2-3-4 : echo 939fb4ab31b2" \
    "stop 939fb4ab31b2 : echo stopped container"

  run bash -c "$PWD/hooks/command && $PWD/hooks/pre-exit"

  assert_success
  assert_output --partial "ran command in docker"
  assert_output --partial "stopped container"

  unstub docker
}

@test "Pull image first before running BUILDKITE_COMMAND" {
  export BUILDKITE_PLUGIN_DOCKER_ALWAYS_PULL=true

  stub docker \
    "pull image:tag : echo pulled latest image" \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "pulled latest image"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-buildkite-agent disabled specifically" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-buildkite-agent enabled but no command" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=true
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "🚨 Failed to find buildkite-agent"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-buildkite-agent enabled but with command" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=true
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN '--volume' '/tmp/bin/buildkite-agent:/usr/bin/buildkite-agent' --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  # only for the command to exist
  stub buildkite-agent \
    " : exit 1"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "🚨 Failed to find buildkite-agent"
  assert_output --partial "ran command in docker"

  unstub docker
  unstub buildkite-agent || true
}

@test "Runs BUILDKITE_COMMAND with volumes" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0=/var/run/docker.sock:/var/run/docker.sock
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with volumes with variables" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  # shellcheck disable=2016 # we want the variable not interpreted now
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0='$ONE_VAR:/var/run/docker.sock'
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --volume $'\$ONE_VAR':/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}


@test "Runs BUILDKITE_COMMAND with volumes with variables and option turned off" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  # shellcheck disable=2016 # we want the variable not interpreted now
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0='$ONE_VAR:/var/run/docker.sock'
  export BUILDKITE_PLUGIN_DOCKER_EXPAND_VOLUME_VARS=false
  export BUILDKITE_COMMAND="pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --volume $'\$ONE_VAR':/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with volumes with variables and option turned on" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  # shellcheck disable=2016  # we want the variable not interpreted now
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0='$ONE_VAR:/var/run/docker.sock'
  export BUILDKITE_PLUGIN_DOCKER_EXPAND_VOLUME_VARS=true
  export BUILDKITE_COMMAND="pwd"

  export ONE_VAR=/my/path

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --volume /my/path:/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with devices" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_DEVICES_0=/dev/bus/usb/001/001
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --device /dev/bus/usb/001/001 --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/app --workdir /app --publish 80:8080 --publish 90:9090 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/app --sysctl net.ipv4.ip_forward=1 --sysctl net.unix.max_dgram_qlen=200 --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with leave-container=false" {
  export BUILDKITE_PLUGIN_DOCKER_LEAVE_CONTAINER=false
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --rm --init --volume /plugin:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with leave-container=true" {
  export BUILDKITE_PLUGIN_DOCKER_LEAVE_CONTAINER=true
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --init --volume /plugin:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-checkout=false" {
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT=false
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --rm --init --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with mount-checkout=true" {
  export BUILDKITE_PLUGIN_DOCKER_WORKDIR=/app
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT=true
  export BUILDKITE_COMMAND="echo hello world; pwd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/app --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/app --volume /var/run/docker.sock:/var/run/docker.sock --workdir /app --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world; pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with environment" {
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_0=MY_TAG=value
  export BUILDKITE_PLUGIN_DOCKER_ENVIRONMENT_1=ANOTHER_TAG=llamas
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env MY_TAG=value --env ANOTHER_TAG=llamas --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with environment files" {
  export BUILDKITE_PLUGIN_DOCKER_ENV_FILE_0='one-path'
  export BUILDKITE_PLUGIN_DOCKER_ENV_FILE_1='a path with spaces'
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env-file one-path --env-file 'a path with spaces' --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}


@test "Runs BUILDKITE_COMMAND with storage-opt" {
  export BUILDKITE_PLUGIN_DOCKER_STORAGE_OPT="size=50G"
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --storage-opt size=50G --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with shm size" {
  export BUILDKITE_PLUGIN_DOCKER_SHM_SIZE=100mb
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --shm-size 100mb --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with pid namespace" {
  export BUILDKITE_PLUGIN_DOCKER_PID=host
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --pid host --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with cpus" {
  export BUILDKITE_PLUGIN_DOCKER_CPUS="0.5"
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --cpus=0.5 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with gpus" {
  export BUILDKITE_PLUGIN_DOCKER_GPUS="0"
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --gpus 0 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env MY_TAG=value --env FOO --env A_VARIABLE --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with a list of propagated env vars" {
  export BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST="LIST_OF_VARS"
  export LIST_OF_VARS="VAR_A VAR_B VAR_C"
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env VAR_A --env VAR_B --env VAR_C --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with a list of propagated env vars - unless you forgot to define the variable" {
  export BUILDKITE_PLUGIN_DOCKER_ENV_PROPAGATION_LIST="LIST_OF_VARS"
  export BUILDKITE_COMMAND="echo hello world"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "env-propagation-list desired, but LIST_OF_VARS is not defined!"
}

@test "Runs BUILDKITE_COMMAND with user" {
  export BUILDKITE_PLUGIN_DOCKER_USER=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir -u foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with userns" {
  export BUILDKITE_PLUGIN_DOCKER_USERNS=foo
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --userns foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with additional groups" {
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_0=foo
  export BUILDKITE_PLUGIN_DOCKER_ADDITIONAL_GROUPS_1=bar
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --group-add foo --group-add bar --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir -u 123:456 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --network foo --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "creating network foo"
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with custom runtime" {
  export BUILDKITE_PLUGIN_DOCKER_RUNTIME=custom_runtime
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --runtime custom_runtime --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with custom IPC option" {
  export BUILDKITE_PLUGIN_DOCKER_IPC=host
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --ipc host --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint without explicit shell" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=/some/custom/entry/point
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint /some/custom/entry/point --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint disabled by empty string" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=''
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint $'''' --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with entrypoint set as false" {
  export BUILDKITE_PLUGIN_DOCKER_ENTRYPOINT=false
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint false --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with shell option as string" {
  export BUILDKITE_PLUGIN_DOCKER_SHELL='custom-bash -a -b'
  export BUILDKITE_COMMAND="echo hello world"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "shell configuration option can no longer be specified as a string, but only as an array"
}

@test "Runs BUILDKITE_COMMAND with shell disabled" {
  export BUILDKITE_PLUGIN_DOCKER_SHELL=false
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with add-host" {
  export BUILDKITE_PLUGIN_DOCKER_ADD_HOST_0=buildkite.fake:127.0.0.1
  export BUILDKITE_PLUGIN_DOCKER_ADD_HOST_1=www.buildkite.local:0.0.0.0
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --add-host buildkite.fake:127.0.0.1 --add-host www.buildkite.local:0.0.0.0 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs with a command as a string" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND="echo hello world"
  export BUILDKITE_COMMAND=

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "🚨 Plugin received a string for BUILDKITE_PLUGIN_DOCKER_COMMAND, expected an array"
}

@test "Runs with a command as an array" {
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_0="echo"
  export BUILDKITE_PLUGIN_DOCKER_COMMAND_1="hello world"
  export BUILDKITE_COMMAND=

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag echo 'hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

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
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --entrypoint llamas.sh --label com.buildkite.job-id=1-2-3-4 image:tag custom-bash -a -b echo 'hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Doesn't disclose environment" {
  export BUILDKITE_COMMAND='echo hello world'
  export SUPER_SECRET=supersecret

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "supersecret"

  unstub docker
}

@test "Run with BUILDKITE_REPO_MIRROR" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  export BUILDKITE_REPO_MIRROR="/tmp/mirrors/git-github-com-buildkite-agent-abc123"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --volume /tmp/mirrors/git-github-com-buildkite-agent-abc123:/tmp/mirrors/git-github-com-buildkite-agent-abc123:ro --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo hello world"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "hello world"

  unstub docker
}

@test "Run with BUILDKITE_REPO_MIRROR but mount-checkout=false" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  export BUILDKITE_REPO_MIRROR="/tmp/mirrors/git-github-com-buildkite-agent-abc123"
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT="false"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT

  stub docker \
    "run -t -i --rm --init --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo hello world"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "hello world"

  unstub docker
}

@test "Run with BUILDKITE_REPO_MIRROR in addition to other volumes" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  export BUILDKITE_REPO_MIRROR="/tmp/mirrors/git-github-com-buildkite-agent-abc123"
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_0="/one:/a"
  export BUILDKITE_PLUGIN_DOCKER_VOLUMES_1="/two:/b:ro"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --volume /one:/a --volume /two:/b:ro --volume /tmp/mirrors/git-github-com-buildkite-agent-abc123:/tmp/mirrors/git-github-com-buildkite-agent-abc123:ro --workdir /workdir --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume /buildkite-agent:/usr/bin/buildkite-agent --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo hello world"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "hello world"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with propagate aws auth tokens" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_PROPAGATE_AWS_AUTH_TOKENS=true

  export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
  export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  export AWS_SESSION_TOKEN="AQoEXAMPLEH4aoAH0gNCAPy...truncated...zrkuWJOgQs8IZZaIv2BXIa2R4Olgk"
  export AWS_REGION="ap-southeast-2"
  export AWS_DEFAULT_REGION="ap-southeast-2"
  export AWS_CONTAINER_CREDENTIALS_FULL_URI="http://localhost:8080/get-credentials"
  export AWS_CONTAINER_CREDENTIALS_RELATIVE_URI="/get-credentials?a=1"
  export AWS_CONTAINER_AUTHORIZATION_TOKEN="Basic abcd"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_SESSION_TOKEN --env AWS_REGION --env AWS_DEFAULT_REGION --env AWS_CONTAINER_CREDENTIALS_FULL_URI --env AWS_CONTAINER_CREDENTIALS_RELATIVE_URI --env AWS_CONTAINER_AUTHORIZATION_TOKEN --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Doesn't disclose aws auth tokens" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_PROPAGATE_AWS_AUTH_TOKENS=true

  export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
  export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  export AWS_SESSION_TOKEN="AQoEXAMPLEH4aoAH0gNCAPy...truncated...zrkuWJOgQs8IZZaIv2BXIa2R4Olgk"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY --env AWS_SESSION_TOKEN --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  refute_output --partial "AKIAIOSFODNN7EXAMPLE"
  refute_output --partial "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  refute_output --partial "AQoEXAMPLEH4aoAH0gNCAPy...truncated...zrkuWJOgQs8IZZaIv2BXIa2R4Olgk"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with memory options" {
  export BUILDKITE_PLUGIN_DOCKER_MEMORY=2g
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --memory=2g --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with memory-swap options" {
  export BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAP=2g
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --memory-swap=2g --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with memory-swappiness options" {
  export BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAPPINESS=0
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --memory-swappiness=0 --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with implicit no swap" {
  export BUILDKITE_PLUGIN_DOCKER_MEMORY_SWAP=2g
  export BUILDKITE_PLUGIN_DOCKER_MEMORY=2g
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --memory=2g --memory-swap=2g --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with one added capability" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_ADD_CAPS_0='cap-0'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --cap-add cap-0 --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with multiple added capabilities" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_ADD_CAPS_0='cap-0'
  export BUILDKITE_PLUGIN_DOCKER_ADD_CAPS_1='cap-1'
  export BUILDKITE_PLUGIN_DOCKER_ADD_CAPS_2='cap-2'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --cap-add cap-0 --cap-add cap-1 --cap-add cap-2 --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with one dropped capability" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_DROP_CAPS_0='cap-0'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --cap-drop cap-0 --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with multiple dropped capabilities" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_DROP_CAPS_0='cap-0'
  export BUILDKITE_PLUGIN_DOCKER_DROP_CAPS_1='cap-1'
  export BUILDKITE_PLUGIN_DOCKER_DROP_CAPS_2='cap-2'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --cap-drop cap-0 --cap-drop cap-1 --cap-drop cap-2 --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with one security opt" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_SECURITY_OPTS_0='sec-0=1'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --security-opt 'sec-0=1' --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with multiple security opts" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_SECURITY_OPTS_0='sec-0=1'
  export BUILDKITE_PLUGIN_DOCKER_SECURITY_OPTS_1='sec-1:0'
  export BUILDKITE_PLUGIN_DOCKER_SECURITY_OPTS_2='sec-2=1:0'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --security-opt 'sec-0=1' --security-opt 'sec-1:0' --security-opt 'sec-2=1:0'  --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with one ulimit" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_ULIMITS_0='nofile=1024'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --ulimit 'nofile=1024' --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}


@test "Runs BUILDKITE_COMMAND with multiple ulimits" {
  export BUILDKITE_COMMAND="echo hello world"
  export BUILDKITE_PLUGIN_DOCKER_ULIMITS_0='nofile=1024'
  export BUILDKITE_PLUGIN_DOCKER_ULIMITS_1='nproc=2048'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --ulimit 'nofile=1024' --ulimit 'nproc=2048' --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND without interactive option" {
  export BUILDKITE_PLUGIN_DOCKER_INTERACTIVE=0
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with interactive option" {
  export BUILDKITE_PLUGIN_DOCKER_INTERACTIVE=1
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND without tty option" {
  export BUILDKITE_PLUGIN_DOCKER_TTY=0
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with tty option" {
  export BUILDKITE_PLUGIN_DOCKER_TTY=1
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Run with BUILDKITE_COMMAND that exits with a failure" {
  export BUILDKITE_COMMAND='pwd'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : exit 1"

  run "$PWD"/hooks/command

  assert_failure
  assert_output --partial "Running command in"

  unstub docker
}

@test "Run with BUILDKITE_COMMAND propagates exit codes" {
  export BUILDKITE_COMMAND='pwd'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : exit 2"

  run "$PWD"/hooks/command

  assert_failure 2
  assert_output --partial "Running command in"

  unstub docker
}


@test "Run with BUILDKITE_COMMAND propagates subshell exit codes" {
  export BUILDKITE_COMMAND='pwd'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'pwd' : sh -c 'exit 2'"

  run "$PWD"/hooks/command

  assert_failure 2
  assert_output --partial "Running command in"

  unstub docker
}

@test "Run with multi-line BUILDKITE_COMMAND" {
  export BUILDKITE_COMMAND=$'echo\ntest'

  stub docker \
    "run -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label \* image:tag /bin/sh -e -c \* : echo Ran \${16}"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "Running command in"
  assert_output --partial "command received has multiple lines"

  unstub docker
}

@test "Use ssh agent (true)" {
  skip 'Can not create a socket for testing :('
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_SSH_AGENT=true
  export SSH_AUTH_SOCK="/tmp/sock" 
  touch /tmp/sock # does not work as the hook checks that this is a socket

  stub docker \
    "run -t -i --rm --init --volume \* --workdir \* --env SSH_AUTH_SOCK=/ssh-agent --volume /tmp/sock:/ssh-agent --volume /root/.ssh/known_hosts:/root/.ssh/known_hosts --label \* image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Use ssh agent (with path)" {
  skip 'Can not create a socket for testing :('
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_SSH_AGENT=/test/path
  export SSH_AUTH_SOCK="/tmp/sock" 
  touch /tmp/sock # does not work as the hook checks that this is a socket

  stub docker \
    "run -t -i --rm --init --volume \* --workdir \* --env SSH_AUTH_SOCK=/ssh-agent --volume /tmp/sock:/ssh-agent --volume /root/.ssh/known_hosts:/test/path/.ssh/known_hosts --label \* image:tag /bin/sh -e -c 'pwd' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}

@test "Runs BUILDKITE_COMMAND with a set of arbitrary flags" {
  export BUILDKITE_PLUGIN_DOCKER_ARBITRARY_FLAGS="echo --test1=1 --test2=2"
  export BUILDKITE_COMMAND="echo hello world"

  stub docker \
    "run --test1=1 --test2=2 -t -i --rm --init --volume $PWD:/workdir --workdir /workdir --label com.buildkite.job-id=1-2-3-4 image:tag /bin/sh -e -c 'echo hello world' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
}
