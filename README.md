# Docker Buildkite Plugin [![Build status](https://badge.buildkite.com/b813517b8bb70d455106a03fbfbb1986477deb7c68f9ffcf59.svg?branch=master)](https://buildkite.com/buildkite/plugins-docker)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

Also see the [Docker Compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin) which supports building images, `docker-compose.yml`, multiple containers, and overriding many of Docker’s defaults.

## Example

The following pipeline will build a binary in the dist directory using [golang Docker image](https://hub.docker.com/_/golang/) and then uploaded as an artifact.

```yml
steps:
  - command: "go build -o dist/my-app ."
    artifact_paths: "./dist/my-app"
    plugins:
      - docker#v3.8.0:
          image: "golang:1.11"
```

Windows images are also supported:

```yaml
steps:
  - command: "dotnet publish -c Release -o published"
    plugins:
      - docker#v3.8.0:
          image: "microsoft/dotnet:latest"
          always-pull: true
```

If you want to control how your command is passed to the docker container, you can use the `command` parameter on the plugin directly:

```yml
steps:
  - plugins:
      - docker#v3.8.0:
          image: "mesosphere/aws-cli"
          always-pull: true
          command: ["s3", "sync", "s3://my-bucket/dist/", "/app/dist"]
    artifact_paths: "dist/**"
```

You can pass in additional environment variables and customize what is mounted into the container:

```yml
steps:
  - command:
      - "yarn install"
      - "yarn run test"
    plugins:
      - docker#v3.8.0:
          image: "node:7"
          always-pull: true
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
      - docker#v3.8.0:
          image: "node:7"
          always-pull: true
          propagate-environment: true
```

AWS authentication tokens can be automatically propagated to the container, for example from an assume role plugin:

```yml
steps:
  - command:
      - "yarn install"
      - "yarn run test"
    env:
      MY_SPECIAL_BUT_PUBLIC_VALUE: kittens
    plugins:
      - docker#v3.8.0:
          image: "node:7"
          always-pull: true
          propagate-aws-auth-tokens: true
```

You can pass in additional volumes to be mounted. This is useful for running Docker:

```yml
steps:
  - command:
      - "docker build . -t image:tag"
      - "docker push image:tag"
    plugins:
      - docker#v3.8.0:
          image: "docker:latest"
          always-pull: true
          volumes:
            - "/var/run/docker.sock:/var/run/docker.sock"
```

You can disable the default behaviour of mounting in the checkout to `workdir`:

```yml
steps:
  - command: "npm start"
    plugins:
      - docker#v3.8.0:
          image: "node:7"
          always-pull: true
          mount-checkout: false
```

## Configuration

### Required

### `image` (required, string)

The name of the Docker image to use.

Example: `node:7`

### Optional

### `add-host` (optional, array)

Additional lines can be added to `/etc/hosts` in the container, in an array of mappings. See https://docs.docker.com/engine/reference/run/#managing-etchosts for more details.

Example: `buildkite.fake:123.0.0.7`

### `additional-groups` (optional, array)

Additional groups to be added to the user in the container, in an array of group names (or ids). See https://docs.docker.com/engine/reference/run/#additional-groups for more details.

Example: `docker`

### `always-pull` (optional, boolean)

Whether to always pull the latest image before running the command. Useful if the image has a `latest` tag.

Default: `false`

### `cap-add` (optional, array)

Add Linux capabilities to the container. Each entry corresponds to a Docker CLI `--cap-add` parameter.

### `cap-drop` (optional, array)

Remove Linux capabilities from the container. Each entry corresponds to a Docker CLI `--cap-drop` parameter.

### `command` (optional, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `debug` (optional, boolean)

Enables debug mode, which outputs the full Docker commands that will be run on the agent machine.

Default: `false`

### `entrypoint` (optional, string or boolean)

Override the image’s default entrypoint, and defaults the `shell` option to `false`. See the [docker run --entrypoint documentation](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) for more details. Set it to `false` to disable the default entrypoint for the image.

Example: `/my/custom/entrypoint.sh`

### `environment` (optional, array)

An array of additional environment variables to pass into to the docker container. Items can be specified as either `KEY` or `KEY=value`. Each entry corresponds to a Docker CLI `--env` parameter. Values specified as variable names will be passed through from the outer environment.

Example: `[ "BUILDKITE_MESSAGE", "MY_SECRET_KEY", "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens" ]`

### `propagate-environment` (optional, boolean)

Whether or not to automatically propagate all pipeline environment variables into the docker container. Avoiding the need to be specified with `environment`.

Note that only pipeline variables will automatically be propagated (what you see in the Buildkite UI). Variables set in proceeding hook scripts will not be propagated to the container.

### `propagate-aws-auth-tokens` (optional, boolean)

Whether or not to automatically propagate aws authentication environment variables into the docker container. Avoiding the need to be specified with `environment`. This is useful for example if you are using an assume role plugin.

Will propagate `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`, only if they are set already.

### `propagate-uid-gid` (optional, boolean)

Whether to match the user ID and group ID for the container user to the user ID and group ID for the host user. It is similar to specifying `user: 1000:1000`, except it avoids hardcoding a particular user/group ID.

Using this option ensures that any files created on shared mounts from within the container will be accessible to the host user. It is otherwise common to accidentally create root-owned files that Buildkite will be unable to remove, since containers by default run as the root user.

### `privileged` (optional, boolean)

Whether or not to run the container in [privileged mode](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities)

### `init` (optional, boolean)

Whether or not to run an init process inside the container. This ensures that responsibilities like reaping zombie processes are performed inside the container.

See [Docker's documentation](https://docs.docker.com/engine/reference/run/#specify-an-init-process) for background and implementation details.

Default: `true` for Linux and macOS, `false` for Windows.

### `mount-checkout` (optional, boolean)

Whether to automatically mount the current working directory which contains your checked out codebase. Mounts onto `/workdir`, unless `workdir` is set, in which case that will be used.

Default: `true`

### `mount-buildkite-agent` (optional, boolean)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container. Set to `false` if you want to disable, or if you already have your own binary in the image.

Default: `true` for Linux, and `false` for macOS and Windows.

### `mount-ssh-agent` (optional, boolean)

Whether to automatically mount the ssh-agent socket from the host agent machine into the container (at `/ssh-agent`and `/root/.ssh/known_hosts` respectively), allowing git operations to work correctly.

Default: `false`

### `network` (optional, string)

Join the container to the docker network specified. The network will be created if it does not already exist. See https://docs.docker.com/engine/reference/run/#network-settings for more details.

Example: `test-network`

### `pull-retries` (optional, int)

A number of times to retry failed docker pull. Defaults to 3. Only applies when `always-pull` is enabled.

### `runtime` (optional, string)

Specify an explicit docker runtime. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `nvidia`

### `ipc` (optional, string)

Specify the IPC mode to use. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `host`

### `security-opt` (optional, array)

Add security options to the container. Each entry corresponds to a Docker CLI `--security-opt` parameter.

### `shell` (optional, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided an `entrypoint` or `command`.

Example: `[ "powershell", "-Command" ]`

### `shm-size` (optional, string)

Set the size of the `/dev/shm` shared memory filesystem mount inside the docker contianer. If unset, uses the default for the platform (typically `64mb`). See [docker run’s runtime constraints documentation](https://docs.docker.com/engine/reference/run/#runtime-constraints-on-resources) for information on allowed formats.

Example: `2gb`

### `tty` (optional, boolean)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

Default: `true` for Linux and macOS, and `false` for Windows.

### `user` (optional, string)

Allows a user to be set, and override the USER entry in the Dockerfile. See https://docs.docker.com/engine/reference/run/#user for more details.

Example: `root`

### `userns` (optional, string)

Allows to explicitly set the user namespace. This overrides the default docker daemon value. If you use the value `host`, you disable user namespaces for this run. See https://docs.docker.com/engine/security/userns-remap/ for more details. Due to limitations in this feature, a privileged container will override the user specified `userns` value to `host`

Example: `mynamespace`

### `volumes` (optional, array or boolean)

Extra volume mounts to pass to the docker container, in an array. Items are specified as `SOURCE:TARGET`. Each entry corresponds to a Docker CLI `--volume` parameter. Relative local paths are converted to their full-path (e.g `./code:/app`).

Example: `[ "/var/run/docker.sock:/var/run/docker.sock" ]`

### `tmpfs` (optional, array)

Tmpfs mounts to pass to the docker container, in an array. Each entry corresponds to a Docker CLI `--tmpfs` parameter. See Docker's [tmpfs mounts](https://docs.docker.com/storage/tmpfs/) documentation for more information on this feature.

Example: `[ "/tmp", "/root/.cache" ]`

### `workdir`(optional, string)

The working directory to run the command in, inside the container. The default is `/workdir`. This path is also used by `mount-checkout` to determine where to mount the checkout in the container.

Example: `/app`

### `sysctls`(optional, array)

Set namespaced kernel parameters in the container. More information can be found in https://docs.docker.com/engine/reference/commandline/run/.

Example: `--sysctl net.ipv4.ip_forward=1`

### `devices` (optional, array)

You can give builds limited access to a specific device or devices by passing devices to the docker container, in an array. Items are specific as `SOURCE:TARGET` or just `TARGET`. Each entry corresponds to a Docker CLI `--device` parameter.

Example: `[ "/dev/bus/usb/001/001" ]`

### `publish` (optional, array)

You can allow the docker container to publish ports. More information can be found in https://docs.docker.com/config/containers/container-networking/. Each entry corresponds to a Docker CLI `--publish` or `-p` parameter.

Example: `[ "8080:80" ]` (Map TCP port 80 in the container to port 8080 on the Docker host.)

### `cpus` (optional, string)

Set the CPU limit to apply when running the container. More information can be found in https://docs.docker.com/config/containers/resource_constraints/#cpu.

Example: `0.5`

## Developing

You can use the [bk cli](https://github.com/buildkite/cli) to run the test pipeline locally, or just the tests using Docker Compose directly:

```bash
docker-compose run --rm tests
```

## License

MIT (see [LICENSE](LICENSE))
