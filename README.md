# Docker Buildkite Plugin ![Build status](https://badge.buildkite.com/3a4b0903b26c979f265c049c932fb4ff3c055af7a199a17216.svg?branch=master)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

Also see the [Docker Compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin) which supports `docker-compose.yml`, multiple containers, and overriding many of Docker’s defaults.

## Example

The following pipeline will build a binary in the dist directory using [golang Docker image](https://hub.docker.com/_/golang/) and then uploaded as an artifact.

```yml
steps:
  - command: "go build -o dist/my-app ."
    artifact_paths: "./dist/my-app"
    plugins:
      - docker#v2.0.0:
          image: "golang:1.11"
```

Windows images are also supported:

```yaml
steps:
  - command: "dotnet publish -c Release -o published"
    plugins:
      - docker#v2.0.0:
          image: "microsoft/dotnet:latest"
          always-pull: true
```

If you want to control how your command is passed to the docker container, you can use the `command` parameter on the plugin directly, which also disables the default volume mounts:

```yml
steps:
  - plugins:
      - docker#v2.0.0:
          image: "mesosphere/aws-cli"
          always-pull: true
          command: ["s3", "sync", "s3://my-bucket/dist/", "/app/dist"]
          volumes: [ "./:/app" ]
    artifact_paths: "dist/**"
```

You can pass in additional environment variables and customize what is mounted into the container:

```yml
steps:
  - command:
      - "yarn install"
      - "yarn run test"
    plugins:
      - docker#v2.0.0:
          image: "node:7"
          always-pull: true
          workdir: "/app"
          volumes:
            - "./code:/app"
          environment:
            - "MY_SECRET_KEY"
            - "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens"
```

Environment variables available in the step can also automatically be propagated to the container:

```yml
steps:
  - command:
      - "yarn install"
      - "yarn run test"
    env:
      MY_SPECIAL_BUT_PUBLIC_VALUE: kittens
    plugins:
      - docker#v2.0.0:
          image: "node:7"
          always-pull: true
          workdir: "/app"
          volumes:
            - "./code:/app"
          propagate-environment: true
```

You can pass in additional volumes to be mounted. This disables the default mount behaviour of mounting `$PWD` to `/workdir`. This is useful for running Docker :

```yml
steps:
  - commands:
      - "docker build . -t image:tag"
      - "docker push image:tag"
    plugins:
      - docker#v2.0.0:
          image: "docker:latest"
          always-pull: true
          volumes:
            - ".:/work"
            - "/var/run/docker.sock:/var/run/docker.sock"
```

You can disable all mounts, including the default by setting `volumes` to `false`:

```yml
steps:
  - command: "npm start"
    plugins:
      - docker#v2.0.0:
          image: "node:7"
          always-pull: true
          volumes: false
```

## Configuration

### Required

### `image` (required, string)

The name of the Docker image to use.

Example: `node:7`

### Optional

### `additional-groups` (optional, array)

Additional groups to be added to the user in the container, in an array of group names (or ids). See https://docs.docker.com/engine/reference/run/#additional-groups for more details.

Example: `docker`

### `always-pull` (optional, boolean)

Whether to always pull the latest image before running the command. Useful if the image has a `latest` tag.

Default: `false`

### `command` (optional, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `debug` (optional, boolean)

Enables debug mode, which outputs the full Docker commands that will be run on the agent machine.

Default: `false`

### `entrypoint` (optional, string)

Override the image’s default entrypoint, and defaults the `shell` option to `false`. See the [docker run --entrypoint documentation](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) for more details.

Example: `/my/custom/entrypoint.sh`

### `environment` (optional, array)

An array of additional environment variables to pass into to the docker container. Items can be specified as either `KEY` or `KEY=value`. Each entry corresponds to a Docker CLI `--env` parameter. Values specified as variable names will be passed through from the outer environment.

Example: `[ "BUILDKITE_MESSAGE", "MY_SECRET_KEY", "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens" ]`

### `propagate-environment` (optional, boolean)

Whether or not to automatically propagate all pipeline environment variables into the docker container. Avoiding the need to be specified with `environment`.

Note that only pipeline variables will automatically be propagated (what you see in the Buildkite UI). Variables set in proceeding hook scripts will not be propagated to the container.

### `mount-buildkite-agent` (optional, boolean)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container. Set to `false` if you want to disable, or if you already have your own binary in the image.

Default: `true` for Linux, and `false` for macOS and Windows.

### `network` (optional, string)

Join the container to the docker network specified. The network will be created if it does not already exist. See https://docs.docker.com/engine/reference/run/#network-settings for more details.

Example: `test-network`

### `runtime` (optional, string)

Specify an explicit docker runtime. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `nvidia`

### `shell` (optional, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided an `entrypoint` or `command`.

Example: `[ "powershell", "-Command" ]`

### `tty` (optional, boolean)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

Default: `true` for Linux and macOS, and `false` for Windows.

### `user` (optional, string)

Allows a user to be set, and override the USER entry in the Dockerfile. See https://docs.docker.com/engine/reference/run/#user for more details.

Example: `root`

### `volumes` (optional, array or boolean)

Extra volume mounts to pass to the docker container, in an array. Items are specified as `SOURCE:TARGET`. Each entry corresponds to a Docker CLI `--volume` parameter. Relative local paths are converted to their full-path (e.g `.:/app`).

To disable the default mount mounts, set `volumes` to `false`.

Default: `true`
Example: `[ ".:/app", "/var/run/docker.sock:/var/run/docker.sock" ]`

### `workdir`(optional, string)

The working directory to run the command in, inside the container. The default is `/workdir`.

Example: `/app`

## License

MIT (see [LICENSE](LICENSE))
