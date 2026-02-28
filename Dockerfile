ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.1
ARG DEBIAN_VERSION=trixie-20260223-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && apt-get install -y build-essential git \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && \
    mix local.rebar --force

ENV MIX_ENV="prod"

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/runtime.exs config/prod.exs config/
RUN mix deps.compile

COPY lib lib
RUN mix compile

RUN mix release

# Runner
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses6 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN mkdir -p /app/.cache && chown -R nobody:root /app

ENV MIX_ENV="prod"
ENV BUMBLEBEE_CACHE_DIR="/app/.cache/bumblebee"
ENV XLA_CACHE_DIR="/app/.cache/xla"

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/embedding_service ./

USER nobody

CMD ["/app/bin/embedding_service", "start"]
