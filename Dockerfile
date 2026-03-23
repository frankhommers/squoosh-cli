# docker build -t ghcr.io/frankhommers/squoosh-cli:{version} .
# docker run --rm ghcr.io/frankhommers/squoosh-cli --help
FROM node:14.19.0

RUN npm install -g @squoosh/cli

ENTRYPOINT ["squoosh-cli"]
