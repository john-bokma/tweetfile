# Syntax=docker/dockerfile:1
FROM alpine:latest AS base

WORKDIR /app

FROM base AS builder
RUN apk add --no-cache --virtual .build-deps \
        perl-app-cpanminus wget make gcc musl-dev perl-dev \
        openssl openssl-dev zlib-dev \
    && apk add perl \
    && cpanm Try::Tiny Path::Tiny Net::Twitter::Lite Net::OAuth \
    && apk del .build-deps

FROM base AS run
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/bin/perl /usr/bin
COPY --from=builder /usr/lib/ /usr/lib/
COPY --from=builder /usr/share /usr/share

COPY tweetfile.pl .
WORKDIR /data
ENTRYPOINT ["perl", "/app/tweetfile.pl"]
