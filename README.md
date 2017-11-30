# Docker Buildkite Plugin ![Build status](https://badge.buildkite.com/3a4b0903b26c979f265c049c932fb4ff3c055af7a199a17216.svg)

A [Buildkite](https://buildkite.com/) plugin for running pipeline steps in [Docker](https://www.docker.com/) containers

The `buildkite-agent` command line tool (and required environment variables) will also be mounted into the container, allowing you to use it for artifact download, etc.

If you need more control, please see the [docker-compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin).

The docker container has the host buildkite-agent binary mounted in to `/usr/bin/buildkite-agent` and the required environment variables set.

## Example

The following pipeline will run `yarn install` and `yarn run test` inside a Docker container using the [node:7 Docker image](https://hub.docker.com/_/node/):

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.0.0:
        image: "node:7"
        workdir: /app
```

You can pass in additional environment variables:

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.0.0:
        image: "node:7"
        workdir: /app
        environment:
          - MY_SPECIAL_VALUE=1
```

## Configuration

### `image` (required)

The name of the Docker image to use.

Example: `node:7`

### `workdir` (required)

The working directory where the pipeline’s code will be mounted to, and run from, inside the container.

Example: `/app`

### `mount-buildkite-agent` (optional)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container. Defaults to `true`. Set to `false` if you want to disable, or if you already have your own binary in the image.

### `environment` (optional)

Extra environment variables to pass to the docker container, in an array of KEY=VALUE params.

### `shell` (optional)

Plugin will run command under the bash shell by default, this allows selection of alternative shells.

Example: `ash`

### `user` (optional)

Allows a user to be set, and override the USER entry in the Dockerfile

Example: `root`

### `debug` (optional)

Outputs the command to be run, and enables xtrace in the plugin

Example: `true`

## License

MIT (see [LICENSE](LICENSE))
