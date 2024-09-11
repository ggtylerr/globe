FROM node:20-bullseye-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

FROM base AS build
WORKDIR /app
COPY . /app

RUN corepack enable
# Not sure if python3 is required? But it's included
# in API, so installing just in case.
RUN apt-get update && \
    apt-get install -y python3 build-essential

RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
    pnpm install --prod --frozen-lockfile

RUN pnpm deploy --filter=@imput/cobalt-web --prod /prod/web

FROM base AS web
WORKDIR /app

COPY --from=build /prod/web /app
# Hopefully not needed - will need to update context
# if so, like with Invidious, since this is a submodule
# COPY --from=build /app/.git /app/.git

EXPOSE 9001
CMD [ "node", "src/cobalt" ]