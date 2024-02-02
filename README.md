# Docker Buildkite Plugin [![Build status](https://badge.buildkite.com/b813517b8bb70d455106a03fbfbb1986477deb7c68f9ffcf59.svg?branch=master)](https://buildkite.com/buildkite/plugins-docker)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps in [Docker](https://www.docker.com/) containers.

Also see the [Docker Compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin) which supports building images, `docker-compose.yml`, multiple containers, and overriding many of Docker’s defaults.

## Example

### `run`

The following pipeline will build a binary in the dist directory using [golang Docker image](https://hub.docker.com/_/golang/) and then uploaded as an artifact.

```yml
steps:
  - command: "go build -o dist/my-app ."
    artifact_paths: "./dist/my-app"
    plugins:
      - docker#v5.9.0:
          image: "golang:1.11"
```

Windows images are also supported:

```yaml
steps:
  - command: "dotnet publish -c Release -o published"
    plugins:
      - docker#v5.9.0:
          image: "microsoft/dotnet:latest"
          always-pull: true
```

:warning: Warning: you should be careful when using an array or multi-line string as the command at the step level with this plugin. You will need to ensure that each line finishes with `;`, execute a script in your repository or use the plugin's [`command` option](#command-optional-array) instead. You will also have to take into account the image's entrypoint and [`shell` option](#shell-optional-array-or-boolean).

If you want to control how your command is passed to the docker container, you can use the `command` parameter on the plugin directly:

```yml
steps:
  - plugins:
      - docker#v5.9.0:
          image: "mesosphere/aws-cli"
          always-pull: true
          command: ["s3", "sync", "s3://my-bucket/dist/", "/app/dist"]
    artifact_paths: "dist/**"
```

You can pass in additional environment variables and customize what is mounted into the container.

Note: If you are utilizing Buildkite's [Elastic CI Stack S3 Secrets plugin](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks), you must specify the environment variable key names as they appear in your S3 bucket's `environment` hook in order to access the secret from within your container.

```yml
steps:
  - command: "yarn install; yarn run test"
    plugins:
      - docker#v5.9.0:
          image: "node:7"
          always-pull: true
          environment:
            - "MY_SECRET_KEY"
            - "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens"
```

Environment variables available in the step can also automatically be propagated to the container:

Note: this will not automatically propagate [Elastic CI Stack S3 Secrets plugin](https://github.com/buildkite/elastic-ci-stack-s3-secrets-hooks) `environment` variables. Refer above for explicitly importing values from that plugin.

```yml
steps:
  - command: "yarn install; yarn run test"
    env:
      MY_SPECIAL_BUT_PUBLIC_VALUE: kittens
    plugins:
      - docker#v5.9.0:
          image: "node:7"
          always-pull: true
          propagate-environment: true
```

AWS authentication tokens can be automatically propagated to the container, for example from an assume role plugin or ECS IAM role:

```yml
steps:
  - command: "yarn install; yarn run test"
    env:
      MY_SPECIAL_BUT_PUBLIC_VALUE: kittens
    plugins:
      - docker#v5.9.0:
          image: "node:7"
          always-pull: true
          propagate-aws-auth-tokens: true
```

You can pass in additional volumes to be mounted. This is useful for running Docker:

```yml
steps:
  - command: "docker build . -t image:tag; docker push image:tag"
    plugins:
      - docker#v5.9.0:
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
      - docker#v5.9.0:
          image: "node:7"
          always-pull: true
          mount-checkout: false
```

Variable interpolation can be tricky due to the 3 layers involved (Buildkite, agent VM, and docker). For example, if you want to use [ECR Buildkite plugin](https://github.com/buildkite-plugins/ecr-buildkite-plugin), you will need to use the following syntax. Note the `$$` prefix for variables that would otherwise resolve at pipeline upload time, not runtime:

```yml
steps:
  - command: "yarn install; yarn run test"
    plugins:
      - ecr#v2.7.0:
          login: true
          account_ids:
          - "d"
          - "p"
          region: us-west-2
          no-include-email: true
      - docker#v5.9.0:
          image: "d.dkr.ecr.us-west-2.amazonaws.com/imagename"
          command: ["./run-integration-tests.sh"]
          expand-volume-vars: true
          volumes:
            - "/var/run/docker.sock:/var/run/docker.sock"
            - "$$BUILDKITE_DOCKER_CONFIG_TEMP_DIRECTORY/config.json:/root/.docker/config.json"
          propagate-environment: true
          environment:
            - "BUILDKITE_DOCKER_CONFIG_TEMP_DIRECTORY"

```

You can read more about runtime variable interpolation from the [docs](https://buildkite.com/docs/pipelines/environment-variables#runtime-variable-interpolation).


### `load`

If the image that you want to run is not in a registry the `load` property can be used to load an image from a tar file.

This can be useful if a previous step builds an image and uploads it as an artifact. The below example shows how a artifact can be downloaded and then passed to the `load` property to load the image which can then be referred to in the `image` property to start a container and run a command as explained above.

```yml
steps:
  - command: "npm start"
    plugins:
      - artifacts#v1.9.0:
          download: "node-7-image.tar.gz"
      - docker#v5.9.0:
          load: "node-7-image.tar.gz"
          image: "node:7"
```

### 🚨 Warning

You need to be careful when/if [running the BuildKite agent itself in docker](https://buildkite.com/docs/agent/v3/docker) that, itself, runs pipelines that use this plugin. Make sure to read all the documentation on the matter, specially the caveats and warnings listed.

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

### `command` (optional, array)

Sets the command for the Docker image, and defaults the `shell` option to `false`. Useful if the Docker image has an entrypoint, or doesn't contain a shell.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `debug` (optional, boolean)

Enables debug mode, which outputs the full Docker commands that will be run on the agent machine.

Default: `false`

### `device-read-bps` (optional, array)

Limit read rate from a device (format: `<device-path>:<number>[<unit>]`). Number is a positive integer. Unit can be one of `kb`, `mb`, or `gb`.

Example: `["/dev/sda1:200mb"]`

### `device-read-iops` (optional, array)

Limit read rate (IO per second) from a device (format: `<device-path>:<number>`). Number is a positive integer.

Example: `["/dev/sda1:400"]`

### `device-write-bps` (optional, array)

Limit write rate to a device (format: `<device-path>:<number>[<unit>]`). Number is a positive integer. Unit can be one of `kb`, `mb`, or `gb`.

Example: `["/dev/sda1:200mb"]`

### `device-write-iops` (optional, array)

Limit write rate (IO per second) to a device (format: `<device-path>:<number>`). Number is a positive integer.

Example: `["/dev/sda1:400"]`

### `entrypoint` (optional, string)

Override the image’s default entrypoint, and defaults the `shell` option to `false`. See the [docker run --entrypoint documentation](https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime) for more details. Set it to `""` (empty string) to disable the default entrypoint for the image, but note that you may need to use this plugin's `command` option instead of the top-level `command` option or set a `shell` instead (depending on the command you want/need to run - see [Issue 138](https://github.com/buildkite-plugins/docker-buildkite-plugin/issues/138) for more information).

Example: `/my/custom/entrypoint.sh`, `""`

### `environment` (optional, array)

An array of additional environment variables to pass into to the docker container. Items can be specified as either `KEY` or `KEY=value`. Each entry corresponds to a Docker CLI `--env` parameter. Values specified as variable names will be passed through from the outer environment.

Example: `[ "BUILDKITE_MESSAGE", "MY_SECRET_KEY", "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens" ]`

### `env-file` (optional, array)

An array of additional files to pass into to the docker container as environment variables. Each entry corresponds to a Docker CLI `--env-file` parameter.

### `env-propagation-list` (optional, string)

If you set this to `VALUE`, and `VALUE` is an environment variable containing a space-separated list of environment variables such as `A B C D`, then A, B, C, and D will all be propagated to the container. This is helpful when you've set up an `environment` hook to export secrets as environment variables, and you'd also like to programmatically ensure that secrets get propagated to containers, instead of listing them all out.

### `expand-image-vars` (optional, boolean, unsafe)

When set to true, it will activate interpolation of variables in the elements of the `image` configuration variable. When turned off (the default), attempting to use variables will fail as the literal `$VARIABLE_NAME` string will be passed as the image name.

Environment variable interporation rules apply here. `$VARIABLE_NAME` is resolved at pipeline upload time, whereas `$$VARIABLE_NAME` is at run time. All things being equal, you likely want `$$VARIABLE_NAME`.

:warning: **Important:** this is considered an unsafe option as the most compatible way to achieve this is to run the strings through `eval` which could lead to arbitrary code execution or information leaking if you don't have complete control of the pipeline

### `propagate-environment` (optional, boolean)

Whether or not to automatically propagate all* pipeline environment variables into the docker container. Avoiding the need to be specified with `environment`.

Note that only pipeline variables will automatically be propagated (what you see in the Buildkite UI). Variables set in proceeding hook scripts will not be propagated to the container.

\* Caveat: only environment variables listed in $BUILDKITE_ENV_FILE will be propagated. This does not include e.g. variables that you exported in an `environment` hook. If you wish for those to be propagated, try `env-propagation-list`.

### `propagate-aws-auth-tokens` (optional, boolean)

Whether or not to automatically propagate aws authentication environment variables into the docker container. Avoiding the need to be specified with `environment`. This is useful for example if you are using an assume role plugin or you want to pass the role of an agent running in ECS or EKS to the docker container.

Will propagate `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `AWS_STS_REGIONAL_ENDPOINTS`, `AWS_WEB_IDENTITY_TOKEN_FILE`, `AWS_ROLE_ARN`, `AWS_CONTAINER_CREDENTIALS_FULL_URI`, `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`, and `AWS_CONTAINER_AUTHORIZATION_TOKEN`, only if they are set already.

When the `AWS_WEB_IDENTITY_TOKEN_FILE` is specified, it will also mount it automatically for you and make it usable within the container.

### `propagate-uid-gid` (optional, boolean)

Whether to match the user ID and group ID for the container user to the user ID and group ID for the host user. It is similar to specifying `user: 1000:1000`, except it avoids hardcoding a particular user/group ID.

Using this option ensures that any files created on shared mounts from within the container will be accessible to the host user. It is otherwise common to accidentally create root-owned files that Buildkite will be unable to remove, since containers by default run as the root user.

### `privileged` (optional, boolean)

Whether or not to run the container in [privileged mode](https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities)

### `init` (optional, boolean)

Whether or not to run an init process inside the container. This ensures that responsibilities like reaping zombie processes are performed inside the container.

See [Docker's documentation](https://docs.docker.com/engine/reference/run/#specify-an-init-process) for background and implementation details.

Default: `true` for Linux and macOS, `false` for Windows.

### `leave-container` (optional, boolean)

Whether or not to leave the container after the run, or immediately remove it with `--rm`.

Default: `false`

### `load` (optional, string)

Specify a file to load a docker image from. If omitted no load will be done.

### `mount-checkout` (optional, boolean)

Whether to automatically mount the current working directory which contains your checked out codebase. Mounts onto `/workdir`, unless `workdir` is set, in which case that will be used.

Default: `true`

### `mount-buildkite-agent` (optional, boolean)

Whether to automatically mount the `buildkite-agent` binary from the host agent machine into the container.

Set to `true` if you want to enable and are sure that the binary running in the agent is compatible with the container's architecture and environment (for example, don't try to mount the OS X or Windows agent binary in a container running linux). If enabled in Windows agents your pipeline, step or agent **must have the `BUILDKITE_AGENT_BINARY_PATH` environment variable defined** with the executable to mount in the (Windows) agent.

Default: `false`

**Important:** enabling this option will share `BUILDKITE_AGENT_TOKEN` environment variable (and others) with the container

### `mount-ssh-agent` (optional, boolean or string)

Whether to mount the ssh-agent socket (at `/ssh-agent`) from the host agent machine into the container or not. Instead of just `true` or `false`, you can specify absolute path in the container for the home directory of the user used to run on which the agent's `.ssh/known_hosts` will be mounted (by default, `/root`).

Default: `false`

**Important**: note that for this to work you will need the agent itself to have access to an ssh agent that is: up and running, listening on the appropriate socket, with the appropriate credentials loaded (or to be loaded). Please refer to the [agent's documentation on using SSH agent](https://buildkite.com/docs/agent/v3/ssh-keys#using-multiple-keys-with-ssh-agent) for more information

### `network` (optional, string)

Join the container to the docker network specified. The network will be created if it does not already exist. See https://docs.docker.com/engine/reference/run/#network-settings for more details.

Example: `test-network`

### `platform` (optional, string)

Platform defines the target platform containers for this service will run on, using the os[/arch[/variant]] syntax. The values of os, arch, and variant MUST conform to the convention used by the OCI Image Spec.

Example: `linux/arm64`

### `pid` (optional, string)

PID namespace provides separation of processes. The PID Namespace removes the view of the system processes, and allows process ids to be reused including pid 1. See https://docs.docker.com/engine/reference/run/#pid-settings---pid for more details. By default, all containers have the PID namespace enabled.

Example: `host`

### `gpus` (optional, string)

GPUs selector. Dependencies: nvidia-container-runtime

Example: `all`

### `pull-retries` (optional, int)

A number of times to retry failed docker pull. Defaults to 3. Only applies when `always-pull` is enabled.

### `runtime` (optional, string)

Specify an explicit docker runtime. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `nvidia`

### `ipc` (optional, string)

Specify the IPC mode to use. See the [docker run options documentation](https://docs.docker.com/engine/reference/commandline/run/#options) for more details.

Example: `host`

### `run-labels` (optional, boolean)

If set to true, adds useful Docker labels to the container. See [Container Labels](#container-labels) for more info.

The default is `true`.

### `shell` (optional, array or boolean)

Set the shell to use for the command. Set it to `false` to pass the command directly to the `docker run` command. The default is `["/bin/sh", "-e", "-c"]` unless you have provided an `entrypoint` or `command`.

Example: `[ "powershell", "-Command" ]`

### `shm-size` (optional, string)

Set the size of the `/dev/shm` shared memory filesystem mount inside the docker contianer. If unset, uses the default for the platform (typically `64mb`). See [docker run’s runtime constraints documentation](https://docs.docker.com/engine/reference/run/#runtime-constraints-on-resources) for information on allowed formats.

Example: `2gb`

### `skip-checkout` (optional, boolean)

Whether to skip the repository checkout phase.

Default: `false`

### `storage-opt` (optional, string)

This allows setting the container rootfs size at the creation time. This is only available for the `devicemapper`, `btrfs`, `overlay2`, `windowsfilter` and `zfs` graph drivers. See [docker documentation](https://docs.docker.com/engine/reference/commandline/run/#set-storage-driver-options-per-container) for more details.

Example: `size=120G`

### `tty` (optional, boolean)

If set to false, doesn't allocate a TTY. This is useful in some situations where TTY's aren't supported, for instance windows.

Default: `true` for Linux and macOS, and `false` for Windows.

### `interactive` (optional, boolean)

If set to false, doesn't connect `stdin` to the process. Some scripts fall back to asking for user input in case of errors, if the process has `stdin` connected and this results in the process waiting for input indefinitely.

### `user` (optional, string)

Allows a user to be set, and override the USER entry in the Dockerfile. See https://docs.docker.com/engine/reference/run/#user for more details.

Example: `root`

### `userns` (optional, string)

Allows to explicitly set the user namespace. This overrides the default docker daemon value. If you use the value `host`, you disable user namespaces for this run. See https://docs.docker.com/engine/security/userns-remap/ for more details. Due to limitations in this feature, a privileged container will override the user specified `userns` value to `host`

Example: `mynamespace`

### `volumes` (optional, array or boolean)

Extra volume mounts to pass to the docker container, in an array. Items are specified as `SOURCE:TARGET`. Each entry corresponds to a Docker CLI `--volume` parameter. Relative local paths are converted to their full-path (e.g `./code:/app`).

Example: `[ "/var/run/docker.sock:/var/run/docker.sock" ]`

### `expand-volume-vars` (optional, boolean, run only, unsafe)

When set to true, it will activate interpolation of variables in the elements of the `volumes` configuration array. When turned off (the default), attempting to use variables will fail as the literal `$VARIABLE_NAME` string will be passed to the `-v` option.

Environment variable interporation rules apply here. `$VARIABLE_NAME` is resolved at pipeline upload time, whereas `$$VARIABLE_NAME` is at run time. All things being equal, you likely want `$$VARIABLE_NAME`.

:warning: **Important:** this is considered an unsafe option as the most compatible way to achieve this is to run the strings through `eval` which could lead to arbitrary code execution or information leaking if you don't have complete control of the pipeline

### `tmpfs` (optional, array)

Tmpfs mounts to pass to the docker container, in an array. Each entry corresponds to a Docker CLI `--tmpfs` parameter. See Docker's [tmpfs mounts](https://docs.docker.com/storage/tmpfs/) documentation for more information on this feature.

Example: `[ "/tmp", "/root/.cache" ]`

### `workdir`(optional, string)

The working directory to run the command in, inside the container. The default is `/workdir`. This path is also used by `mount-checkout` to determine where to mount the checkout in the container.

Example: `/app`

### `sysctls`(optional, array)

Set namespaced kernel parameters in the container. More information can be found in https://docs.docker.com/engine/reference/commandline/run/.

Example: `--sysctl net.ipv4.ip_forward=1`

### `add-caps` (optional, array)

Add Linux capabilities to the container. Each entry corresponds to a Docker CLI `--cap-add` parameter.

### `drop-caps` (optional, array)

Remove Linux capabilities from the container. Each entry corresponds to a Docker CLI `--cap-drop` parameter.

### `security-opts` (optional, array)

Add security options to the container. Each entry corresponds to a Docker CLI `--security-opt` parameter.

### `ulimits` (optional, array)

Add ulimit options to the container. Each entry corresponds to a Docker CLI `--ulimit` parameter.

### `devices` (optional, array)

You can give builds limited access to a specific device or devices by passing devices to the docker container, in an array. Items are specific as `SOURCE:TARGET` or just `TARGET`. Each entry corresponds to a Docker CLI `--device` parameter.

Example: `[ "/dev/bus/usb/001/001" ]`

### `publish` (optional, array)

You can allow the docker container to publish ports. More information can be found in https://docs.docker.com/config/containers/container-networking/. Each entry corresponds to a Docker CLI `--publish` or `-p` parameter.

Example: `[ "8080:80" ]` (Map TCP port 80 in the container to port 8080 on the Docker host.)

### `cpus` (optional, string)

Set the CPU limit to apply when running the container. More information can be found in https://docs.docker.com/config/containers/resource_constraints/#cpu.

Example: `0.5`

### `memory` (optional, string)

Set the memory limit to apply when running the container. More information can
be found in https://docs.docker.com/config/containers/resource_constraints/#limit-a-containers-access-to-memory.

Example: `2g`

### `memory-swap` (optional, string)

Set the memory swap limit to apply when running the container. More information
can be found in https://docs.docker.com/config/containers/resource_constraints/#limit-a-containers-access-to-memory.

Example: `2g`

### `memory-swappiness` (optional, string)

Set the swappiness level to apply when running the container. More information
can be found in https://docs.docker.com/config/containers/resource_constraints/#--memory-swappiness-details.

Example: `0`

## Container Labels

When running a command, the plugin will automatically add the following Docker labels to the container:
- `com.buildkite.pipeline_name=${BUILDKITE_PIPELINE_NAME}`
- `com.buildkite.pipeline_slug=${BUILDKITE_PIPELINE_SLUG}`
- `com.buildkite.build_number=${BUILDKITE_BUILD_NUMBER}`
- `com.buildkite.job_id=${BUILDKITE_JOB_ID}`
- `com.buildkite.job_label=${BUILDKITE_LABEL}`
- `com.buildkite.step_key=${BUILDKITE_STEP_KEY}`
- `com.buildkite.agent_name=${BUILDKITE_AGENT_NAME}`
- `com.buildkite.agent_id=${BUILDKITE_AGENT_ID}`

These labels can make it easier to query containers on hosts using `docker ps` for example:

```bash
docker ps --filter "label=com.buildkite.job_label=Run tests"
```

This behaviour can be disabled with the `run-labels: false` option.

## Developing

To run testing, shellchecks and plugin linting use use `bk run` with the [Buildkite CLI](https://github.com/buildkite/cli).

```bash
bk run
```

Or if you want to run just the tests, you can use the docker [Plugin Tester](https://github.com/buildkite-plugins/buildkite-plugin-tester):

```bash
docker run --rm -ti -v "${PWD}":/plugin buildkite/plugin-tester:latest
```

## License

MIT (see [LICENSE](LICENSE))
