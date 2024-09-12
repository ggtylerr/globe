FROM node:20-bullseye-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

FROM base AS build
WORKDIR /app
COPY /services/cobalt /app

RUN corepack enable
RUN apt-get update && \
    apt-get install -y python3 build-essential curl

RUN rm /app/.git
COPY /.git/modules/services/cobalt /app/.git

WORKDIR /app/web
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --frozen-lockfile

ARG WEB_HOST
ARG WEB_PLAUSIBLE_HOST
ARG WEB_DEFAULT_API
ARG WEB_TURNSTILE_KEY
ENV WEB_HOST=${WEB_HOST}
ENV WEB_PLAUSIBLE_HOST=${WEB_PLAUSIBLE_HOST}
ENV WEB_DEFAULT_API=${WEB_DEFAULT_API}
ENV WEB_TURNSTILE_KEY=${WEB_TURNSTILE_KEY}

RUN pnpm run build

EXPOSE 8080
# Using npx http-server instead of Vite since
# for some reason Vite is unable to serve basic
# static content. Thanks, Vite!
RUN npm install http-server -g
WORKDIR /app/web/build
CMD [ "http-server" ]
