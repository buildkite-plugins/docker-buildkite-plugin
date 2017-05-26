# Docker Buildkite Plugin

A [Buildkite](https://buildkite.com/) Docker plugin allowing you to run a command in a [Docker](https://www.docker.com/) container.

If you need more control, please see the [docker-compose Buildkite Plugin](https://github.com/buildkite-plugins/docker-compose-buildkite-plugin).

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

## Configuration

### `image` (required)

The name of the Docker image to use.

Example: `node:7`

### `workdir` (required)

The working directory where the pipeline’s code will be mounted to, and run from, inside the container.

Example: `/app`

## License

MIT (see [LICENSE](LICENSE))