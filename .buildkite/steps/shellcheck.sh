#!/bin/bash
docker run -it -v "$PWD":/mnt:ro koalaman/shellcheck \
  hooks/**
