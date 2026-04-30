ARG ELIXIR_VERSION=1.19.5
ARG OTP_VERSION=28
ARG FOUNDRY_IMAGE=ghcr.io/foundry-rs/foundry:v1.5.1

FROM ${FOUNDRY_IMAGE} AS foundry

FROM elixir:${ELIXIR_VERSION}-otp-${OTP_VERSION} AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends build-essential git ca-certificates nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force
COPY --from=foundry /usr/local/bin/cast /usr/local/bin/cast

COPY platform/mix.exs platform/mix.lock platform/
COPY elixir-utils elixir-utils

WORKDIR /workspace/platform

COPY platform/config config
COPY platform/lib lib
COPY platform/priv priv
COPY platform/rel rel
COPY platform/assets assets

RUN mix deps.get --only prod
RUN mix deps.compile
RUN npm --prefix assets ci
RUN mix assets.deploy
RUN mix compile
RUN mix release

FROM debian:trixie-slim AS app

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV HOME=/app

WORKDIR /app

COPY --from=build /usr/local/bin/cast /usr/local/bin/cast
COPY --from=build /workspace/platform/priv/metadata /app/priv/metadata
COPY --from=build /workspace/platform/_build/prod/rel/platform_phx ./

EXPOSE 4000

CMD ["/app/bin/server"]
