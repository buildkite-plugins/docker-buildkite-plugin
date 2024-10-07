#!/usr/bin/env bats

load "${BATS_PLUGIN_PATH}/load.bash"

@test "Runs chown" {
  export BUILDKITE_PLUGIN_DOCKER_CHOWN=true

  stub docker \
    "run --rm -v $PWD:$PWD busybox chown -Rh $(id -u):$(id -g) $PWD : echo cleaned"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial "cleaned"

  unstub docker
}

@test "Doesn't run if not configured" {
  unset BUILDKITE_PLUGIN_DOCKER_CHOWN

  stub docker \
    "run --rm -v $PWD:$PWD busybox chown -Rh $(id -u):$(id -g) $PWD : echo cleaned"

  run "$PWD"/hooks/pre-exit

  assert_success
  refute_output --partial "cleaned"

  unstub docker || true
}

@test "Doesn't run if checkout not mounted" {
  export BUILDKITE_PLUGIN_DOCKER_CHOWN=true
  export BUILDKITE_PLUGIN_DOCKER_MOUNT_CHECKOUT=false

  stub docker \
    "run --rm -v $PWD:$PWD busybox chown -Rh $(id -u):$(id -g) $PWD : echo cleaned"

  run "$PWD"/hooks/pre-exit

  assert_success
  refute_output --partial "cleaned"

  unstub docker || true
}

@test "Use custom image" {
  export BUILDKITE_PLUGIN_DOCKER_CHOWN=true
  export BUILDKITE_PLUGIN_DOCKER_CHOWN_IMAGE=some-image

  stub docker \
    "run --rm -v $PWD:$PWD some-image chown -Rh $(id -u):$(id -g) $PWD : echo cleaned"

  run "$PWD"/hooks/pre-exit

  assert_success
  assert_output --partial "cleaned"

  unstub docker
}
