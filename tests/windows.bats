#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

setup() {
  export BUILDKITE_PLUGIN_DOCKER_IMAGE=image:tag
  export BUILDKITE_JOB_ID="1-2-3-4"
  export BUILDKITE_PLUGIN_DOCKER_CLEANUP=false
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT=false
  export BUILDKITE_COMMAND="pwd"
  export OSTYPE="win" # important to define these test as windows
}

@test "Run with BUILDKITE_COMMAND" {
  export BUILDKITE_COMMAND='command1 "a string"'
  export BUILDKITE_AGENT_BINARY_PATH="/buildkite-agent"
  unset BUILDKITE_PLUGIN_DOCKER_MOUNT_BUILDKITE_AGENT

  stub cmd.exe \
    "//C $'echo %CD%' : echo WIN_PATH"

  stub docker \
    "run -i --rm --volume \* --workdir \* --env BUILDKITE_JOB_ID --env BUILDKITE_BUILD_ID --env BUILDKITE_AGENT_ACCESS_TOKEN --volume \* --label com.buildkite.job-id=1-2-3-4 image:tag CMD.EXE /c 'command1 \"a string\"' : echo ran command in docker"

  run "$PWD"/hooks/command

  assert_success
  assert_output --partial "ran command in docker"

  unstub docker
  unstub cmd.exe
}