# Docker Buildkite Plugin ![Build status](https://badge.buildkite.com/3a4b0903b26c979f265c049c932fb4ff3c055af7a199a17216.svg?branch=master)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

The Docker container will have the host’s `buildkite-agent` binary mounted in to `/usr/bin/buildkite-agent`, and the three required environment variables set for using the artifact upload, download, annotate, etc commands.

If you need more control, please see the [docker-compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin).

## Example

The following pipeline will build a binary in the dist directory using [golang:1.11 Docker image](https://hub.docker.com/_/golang/) and then uploaded as an artifact.

```yml
steps:
  - command: go build -o dist/my-app .
    artifact_paths: ./dist/my-app
    plugins:
      docker#v1.4.0:
        image: "golang:1.11"
```

By default, this will mount in `$PWD` from the host that docker is running on into `/work` in the container, along with the `buildkite-agent` binary and relevant environmental variables.

If you want to control how your command is passed to the docker container, you can use the `command` parameter on the plugin directly:

```yml
steps:
  - plugins:
      docker#v1.4.0:
        image: "koalaman/shellcheck"
        command: ["--exclude=SC2207", "./script.sh"]
```

You can pass in additional environment variables and customize what is mounted into the container:

```yml
steps:
  - command: yarn install && yarn run test
    plugins:
      docker#v1.4.0:
        image: "node:7"
        workdir: /app
        volumes:
          - ./code:/app
        environment:
          - MY_SECRET_KEY
          - MY_SPECIAL_BUT_PUBLIC_VALUE=kittens
```

You can pass in additional volumes to be mounted. This disables the default mount behaviour of mounting `$PWD` to `/workdir`. This is useful for docker-in-docker:

```yml
steps:
  - commands:
      - "docker build . -t image:tag"
      - "docker push image:tag"
    plugins:
      docker#v1.4.0:
        image: "docker:latest"
        volumes:
          - .:/work
          - /var/run/docker.sock:/var/run/docker.sock
```

You can disable all mounts, including the default by setting `volumes` to `false`:

```yml
steps:
  - command: "npm start"
    plugins:
      docker#v1.4.0:
        image: "node:7"
        volumes: false
```

## Configuration

### `image` (required)

The name of the Docker image to use.

Example: `node:7`

### `workdir`(optional)

The working directory to run the command in, inside the container. The default is `/workdir`.

Example: `/app`

### `mount-buildkite-agent` (optional)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container. Defaults to `true` for Linux, but `false` for macOS and Windows. Set to `false` if you want to disable, or if you already have your own binary in the image.

### `volumes` (optional, array or bool)

Extra volume mounts to pass to the docker container, in an array. Items are specified as `SOURCE:TARGET`. Each entry corresponds to a Docker CLI `--volume` parameter, with the addition of relative paths being converted to their full-path (e.g `.:/app`).

Example: `/var/run/docker.sock:/var/run/docker.sock`

### `always-pull` (optional)

Whether to always pull the latest image before running the command. Useful if the image has a `latest` tag. The default is false, the image will only get pulled if not present.

### `environment` (optional, array)

An array of additional environment variables to pass into to the docker container. Items can be specified as either `KEY` or `KEY=value`. Each entry corresponds to a Docker CLI `--env` parameter. Values specified as variable names will be passed through from the outer environment.

Examples: `BUILDKITE_MESSAGE`, `MY_SECRET_KEY`, `MY_SPECIAL_BUT_PUBLIC_VALUE=kittens`

### `tty` (optional)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

The default is `true` for linux or macOS, but `false` for windows.

### `user` (optional)

Allows a user to be set, and override the USER entry in the Dockerfile. See https://docs.docker.com/engine/reference/run/#user for more details.

Example: `root`

### `additional-groups` (optional)

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

### `shell` (optional, array)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided an `entrypoint` or `command`.

Example: `["powershell", "-Command"]`

### `entrypoint` (optional)

Override the image’s default entrypoint, and defaults the `shell` option to `false`. See the [docker run --entrypoint documentation](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) for more details.

Example: `/my/custom/entrypoint.sh`

### `command` (optional, array)

Override the image’s default command, and defaults the `shell` option to `false`.

Example: `["/bin/mycommand", "-c", "test"]`

## License

MIT (see [LICENSE](LICENSE))
