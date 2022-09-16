#!/usr/bin/env bats

load '/usr/local/lib/bats/load.bash'

@test "Run without specific options" {

  run $PWD/hooks/pre-checkout

  assert_success
  refute_line --partial 'Skipping'  # generate no output
}


@test "Run with skip-checkout turned off" {
  export BUILDKITE_PLUGIN_DOCKER_SKIP_CHECKOUT=false

  run $PWD/hooks/pre-checkout

  assert_success
  refute_line --partial 'Skipping' # generate no output
}


@test "Run with skip-checkout turned on" {
  export BUILDKITE_PLUGIN_DOCKER_SKIP_CHECKOUT=true

  run $PWD/hooks/pre-checkout
  assert_success
  assert_output --partial 'Skipping'
}
