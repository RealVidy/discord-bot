#! /usr/bin/env bash

# Assign "prod" tag to current commit
git tag -d prod
git push --delete origin prod
git tag -a prod HEAD -m "prod"
git push origin prod

DOCKER_BUILDKIT=1 fly deploy --remote-only