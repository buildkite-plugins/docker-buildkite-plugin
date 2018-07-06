# Docker Buildkite Plugin ![Build status](https://badge.buildkite.com/3a4b0903b26c979f265c049c932fb4ff3c055af7a199a17216.svg?branch=master)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

The Docker container will have the host’s `buildkite-agent` binary mounted in to `/usr/bin/buildkite-agent`, and the three required environment variables set for using the artifact upload, download, annotate, etc commands.

If you need more control, please see the [docker-compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin).

## Example

The following pipeline will run `yarn install` and `yarn run test` inside a Docker container using the [node:7 Docker image](https://hub.docker.com/_/node/):

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.4.0:
        image: "node:7"
        workdir: /app
```

You can pass in additional environment variables:

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.4.0:
        image: "node:7"
        workdir: /app
        environment:
          - MY_SECRET_KEY
          - MY_SPECIAL_BUT_PUBLIC_VALUE=kittens
```

You can pass in additional volume mounts. This is useful for docker-in-docker:

```yml
steps:
  - command: docker build . -t image:tag
    plugins:
      docker#v1.4.0:
        image: "docker:latest"
        mounts:
          - /var/run/docker.sock:/var/run/docker.sock
```

You can specify a docker network to join. This will be created if it does not already exist:

```yml
steps:
  - command: docker build . -t image:tag
    plugins:
      docker#v1.4.0:
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

Extra volume mounts to pass to the docker container, in an array. Items are specified as `SOURCE:TARGET`. Each entry corresponds to a Docker CLI `--volume` parameter.

Example: `/var/run/docker.sock:/var/run/docker.sock`

### `environment` (optional)

An array of additional environment variables to pass into to the docker container. Items can be specified as either `KEY` or `KEY=value`. Each entry corresponds to a Docker CLI `--env` parameter. Values specified as variable names will be passed through from the outer environment.

Examples: `BUILDKITE_MESSAGE`, `MY_SECRET_KEY`, `MY_SPECIAL_BUT_PUBLIC_VALUE=kittens`

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

### `runtime` (optional)

Specify an explicit docker runtime. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `nvidia`

### `shell` (optional)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker run` command. The default is `bash -e -c`.

Example: `powershell -Command`

### `entrypoint` (optional)

Override the image’s default entrypoint, and defaults the `shell` option to `false`. See the [docker run --entrypoint documentation](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) for more details.

Example: `/my/custom/entrypoint.sh`

## License

MIT (see [LICENSE](LICENSE))
