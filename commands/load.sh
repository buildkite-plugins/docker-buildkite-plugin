#!/bin/bash

set -euo pipefail

arg="${BUILDKITE_PLUGIN_DOCKER_LOAD:-}"

if [[ -z "$arg" ]]; then
  echo "Error: load has to be given a path to the file that should be loaded"
  exit 1
fi

# Don't convert paths on gitbash on windows, as that can mangle user paths and cmd options.
# See https://github.com/buildkite-plugins/docker-buildkite-plugin/issues/81 for more information.
( if is_windows ; then export MSYS_NO_PATHCONV=1; fi && docker load -i "${arg}" )
