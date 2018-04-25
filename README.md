# Docker Buildkite Plugin ![Build status](https://badge.buildkite.com/3a4b0903b26c979f265c049c932fb4ff3c055af7a199a17216.svg?branch=master)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

The docker container has the host buildkite-agent binary mounted in to `/usr/bin/buildkite-agent` and the required environment variables set, allowing you to use it for artifact download, etc.

If you need more control, please see the [docker-compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin).

## Example

The following pipeline will run `yarn install` and `yarn run test` inside a Docker container using the [node:7 Docker image](https://hub.docker.com/_/node/):

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.1.1:
        image: "node:7"
        workdir: /app
```

You can pass in additional environment variables:

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.1.1:
        image: "node:7"
        workdir: /app
        environment:
          - MY_SPECIAL_VALUE=1
```

You can pass in additional volume mounts. This is useful for docker-in-docker:

```yml
steps:
  - command: docker build . -t image:tag
    plugins:
      docker#v1.1.1:
        image: "docker:latest"
        mounts:
          - /var/run/docker.sock:/var/run/docker.sock
```

You can specify a docker network to join. This will be created if it does not already exist:

```yml
steps:
  - command: docker build . -t image:tag
    plugins:
      docker#v1.1.1:
        image: "docker:latest"
        network: "test-network"
```

## Configuration

### `image` (required)

The name of the Docker image to use.

Example: `node:7`

### `workdir`(optional)

The working directory where the pipeline’s code will be mounted to, and run from, inside the container. The default is `/workdir`.

Example: `/app`

### `always-pull` (optional)

Whether to always pull the latest image before running the command. Useful if the image has a `latest` tag. The default is false, the image will only get pulled if not present.

### `mount-buildkite-agent` (optional)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container. Defaults to `true`. Set to `false` if you want to disable, or if you already have your own binary in the image.

### `mounts` (optional)

Extra volume mounts to pass to the docker container, in an array of `SOURCE:TARGET` params

Example: `/var/run/docker.sock:/var/run/docker.sock`

### `environment` (optional)

Extra environment variables to pass to the docker container, in an array of `KEY=VALUE` params.

Example: `MY_SPECIAL_VALUE=1`

### `user` (optional)

Allows a user to be set, and override the USER entry in the Dockerfile. See https://docs.docker.com/engine/reference/run/#user for more details.

Example: `root`

### `additional_groups` (optional)

Additional groups to be added to the user in the container, in an array of group names (or ids). See https://docs.docker.com/engine/reference/run/#additional-groups for more details.

Example: `docker`

### `network` (optional)

Join the container to the docker network specified. The network will be created if it does not already exist. See https://docs.docker.com/engine/reference/run/#network-settings for more details. 

Example: `test-network`

### `debug` (optional)

Outputs the command to be run, and enables xtrace in the plugin

Example: `true`

## License

MIT (see [LICENSE](LICENSE))
