# syntax=docker/dockerfile:1.2

# build base that sets up common dependencies of the build
ARG BUILD_BASE_VERSION=alpine
FROM rust:$BUILD_BASE_VERSION as build-base

RUN apk add --no-cache \
  clang clang-dev clang-libs pkgconfig bearssl-dev git \
  gcc make g++ linux-headers protobuf protobuf-dev musl-dev

RUN set -ex; \
  wget https://github.com/gruntwork-io/fetch/releases/download/v0.4.2/fetch_linux_amd64 -P /; \
  mv /fetch_linux_amd64 /fetch; \
  chmod +x /fetch; \
  /fetch --repo="https://github.com/mozilla/sccache" --tag="~>0.2.15" --release-asset="^sccache-v[0-9.]*-x86_64-unknown-linux-musl.tar.gz$" /; \
  tar -xvf /sccache-v*-x86_64-unknown-linux-musl.tar.gz -C /; \
  mv /sccache-v*-x86_64-unknown-linux-musl/sccache /sccache; \
  rm -rf /sccache-v*-x86_64-unknown-linux-musl /sccache-v*-x86_64-unknown-linux-musl.tar.gz /fetch; \
  chmod +x /sccache;

WORKDIR /build
ARG RUST_TOOLCHAIN=nightly-2021-11-09
RUN rustup install $RUST_TOOLCHAIN && \
  rustup target add wasm32-unknown-unknown --toolchain $RUST_TOOLCHAIN

FROM build-base as build

COPY . .

RUN PROTOC=$(which protoc) \
    PROTOC_INCLUDE=/usr/include \
    RUSTFLAGS=-Ctarget-feature=-crt-static \
    RUSTC_WRAPPER=/sccache \
    SCCACHE_REDIS=redis://localhost:6379 \
    SCCACHE_IDLE_TIMEOUT=0 \
    cargo build --release && \
    rm -rf /build/target \
