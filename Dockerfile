# syntax=docker/dockerfile:1

ARG BUILDPLATFORM="linux/amd64"

FROM --platform=${BUILDPLATFORM} alpine:3.17 AS prepare

ARG CACHEBUST

# hadolint ignore=DL3020
ADD ${CACHEBUST} /.git-hashref

SHELL ["/bin/ash", "-eufo", "pipefail", "-c"]

RUN apk --no-cache add \
    curl=~7.87.0 \
    # sed=~4.9 \
    git=~2.38 \
    # tzdata=~2022f \
    # go=~1.19.5 \
    # bash=~5.2.15 \
    ca-certificates=~20220614 && \
    sync

ARG GIT_REF
ARG PACKAGE_NAME
ARG PACKAGE_VERSION
ARG PACKAGE_VERSION_PREFIX
ARG PACKAGE_URL
ARG PACKAGE_SOURCE_URL
ARG PACKAGE_HEAD_URL
ARG PACKAGE_HEAD=false

# hadolint ignore=SC2015
RUN { [ -n "${PACKAGE_VERSION_PREFIX}" ] && [ -n "${PACKAGE_VERSION}" ] && PACKAGE_VERSION="${PACKAGE_VERSION_PREFIX}${PACKAGE_VERSION}" || true; } && \
    mkdir -p "/usr/local/src/${PACKAGE_NAME}" && \
    [ -n "${PACKAGE_NAME}" ] && \
    { { [ -n "${PACKAGE_HEAD_URL}" ] && \
        git clone "${PACKAGE_HEAD_URL}" "/usr/local/src/${PACKAGE_NAME}" && \
        { { { [ -n "${PACKAGE_VERSION}" ] && [ "${PACKAGE_HEAD}" != true ] && [ "${PACKAGE_HEAD}" != "on" ] && [ "${PACKAGE_HEAD}" != "1" ] && \
              git -C "/usr/local/src/${PACKAGE_NAME}" checkout tags/${PACKAGE_VERSION}; } && \
            { [ -n "${PACKAGE_VERSION}" ] && [ "${PACKAGE_HEAD}" != true ] && [ "${PACKAGE_HEAD}" != "on" ] && [ "${PACKAGE_HEAD}" != "1" ]; }; } || \
          { { ! { [ -n "${PACKAGE_VERSION}" ] && [ "${PACKAGE_HEAD}" != true ] && [ "${PACKAGE_HEAD}" != "on" ] && [ "${PACKAGE_HEAD}" != "1" ] && \
              git -C "/usr/local/src/${PACKAGE_NAME}" checkout tags/${PACKAGE_VERSION}; }; } && \
            { ! { [ -n "${PACKAGE_VERSION}" ] && [ "${PACKAGE_HEAD}" != true ] && [ "${PACKAGE_HEAD}" != "on" ] && [ "${PACKAGE_HEAD}" != "1" ]; }; }; }; }; } || \
      { [ -n "${PACKAGE_SOURCE_URL}" ] && curl -fsSL "${PACKAGE_SOURCE_URL}" | \
        tar -zxC "/usr/local/src/${PACKAGE_NAME}" --strip 1; } || \
      { [ -n "${PACKAGE_URL}" ] && [ -n "${PACKAGE_VERSION}" ] && \
        curl -fsSL "${PACKAGE_URL}/archive/${PACKAGE_VERSION}.tar.gz" | \
        tar -zxC "/usr/local/src/${PACKAGE_NAME}" --strip 1; }; } || false

COPY patch/plugin/forward/forward.go.patch patch/plugin/forward/setup.go.patch /usr/local/src/patch/plugin/forward/

RUN \
    git -C "/usr/local/src/${PACKAGE_NAME}" apply /usr/local/src/patch/plugin/forward/setup.go.patch && \
    git -C "/usr/local/src/${PACKAGE_NAME}" apply /usr/local/src/patch/plugin/forward/forward.go.patch && \
    git -C "/usr/local/src/${PACKAGE_NAME}" status && \
    git -C "/usr/local/src/${PACKAGE_NAME}" diff

# ----------------------------------------------------------------------------

FROM --platform=${BUILDPLATFORM} golang:1.19.5-alpine3.17 AS build

ARG CACHEBUST

# hadolint ignore=DL3020
ADD ${CACHEBUST} /.git-hashref

RUN apk --no-cache add \
    # curl=~7.87.0 \
    sed=~4.9 \
    git=~2.38 \
    # tzdata=~2022f \
    # go=~1.19.5 \
    # bash=~5.2.15 \
    ca-certificates=~20220614 && \
    sync

SHELL ["/bin/ash", "-eufo", "pipefail", "-c"]

ARG PACKAGE_NAME
ARG PACKAGE_VERSION
ARG PACKAGE_URL
ARG PACKAGE_SOURCE_URL
ARG PACKAGE_HEAD_URL
ARG PACKAGE_HEAD=false

ARG TARGETOS TARGETARCH TARGETVARIANT
ARG CGO_ENABLED=0
ARG BUILD_FLAGS="-v"
ARG GO111MODULE
ARG GOPROXY
ARG GOSUMDB

ENV GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH}

COPY --from=prepare /etc/passwd /etc/group /etc/
COPY --from=prepare /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# COPY --from=prepare /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=prepare --chown=nonroot:nonroot /usr/local/src /usr/local/src

WORKDIR /usr/local/src/${PACKAGE_NAME}

RUN --mount=type=cache,target=/home/nonroot/.cache/go-build,uid=65532,gid=65532 \
    --mount=type=cache,target=/go/pkg \
        # cat <<EOF >> go.mod && cat go.mod && \
        sed -i.bak 's|forward:forward|alternate:github.com/coredns/alternate\ndnsredir:github.com/leiless/dnsredir\nforward:forward|g' plugin.cfg && \
        sed -i.bak 's|hosts:hosts|ads:github.com/missdeer/ads\nblocklist:github.com/relekang/coredns-blocklist\nhosts:hosts|g' plugin.cfg && \
        sed -i.bak 's|rewrite:rewrite|rewrite:rewrite\nbogus:github.com/missdeer/bogus\nipset:github.com/missdeer/ipset|g' plugin.cfg && \
        sed -i.bak 's|cache:cache|cache:cache\nredisc:github.com/miekg/redis|g' plugin.cfg && \
        sed -i.bak '/azure/d' plugin.cfg && \
        sed -i.bak '/route53/d' plugin.cfg && \
        sed -i.bak '/clouddns/d' plugin.cfg && \
        cat plugin.cfg && \
        COMMIT_SHA=$(git describe --dirty --always) && \
        TARGETVARIANT=$(printf "%s" "${TARGETVARIANT}" | sed 's/v//g') && \
        CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT} go generate coredns.go && \
        CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT} go get && \
        cat go.mod && git diff go.mod && \
        # go list -m all && go list -m -json all && go mod graph && \
        CGO_ENABLED=${CGO_ENABLED} GOOS=${TARGETOS} GOARCH=${TARGETARCH} GOARM=${TARGETVARIANT} \
        go build ${BUILD_FLAGS} -ldflags="-s -w -X github.com/coredns/coredns/coremain.GitCommit=${COMMIT_SHA}" -o coredns && \
        sync

# replace (
#     github.com/coredns/proxy => ../proxy
# )
# EOF

WORKDIR /etc/${PACKAGE_NAME}

COPY Corefile ./

# ----------------------------------------------------------------------------

FROM --platform=${BUILDPLATFORM} scratch

ARG CACHEBUST

# hadolint ignore=DL3020
ADD ${CACHEBUST} /.git-hashref

ARG PACKAGE_NAME

COPY --from=build /etc/passwd /etc/group /etc/
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
# COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=build /usr/local/src/${PACKAGE_NAME}/${PACKAGE_NAME} /usr/local/bin/
COPY --from=build --chown=nobody:nogroup /etc/${PACKAGE_NAME} /etc/${PACKAGE_NAME}

# TODO: switch to 'nonroot' user
USER nobody

ENTRYPOINT [ "coredns" ]

CMD [ "-conf", "/etc/coredns/Corefile" ]
