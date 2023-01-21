# Usage:
# make        # compile all binary
# make clean  # remove ALL binaries and objects

# git show -s --date=format:'%Y%m%d%H%M%S' --format=%cd 643550eabe37176fd27c8aa9263c8c4206be066d

AUTHOR                     ?= issenn

PACKAGE_NAME               ?= coredns
PACKAGE_VERSION            ?= 1.10.0
PACKAGE_VERSION_PREFIX     ?= v
PACKAGE_URL                ?= https://github.com/coredns/coredns
PACKAGE_SOURCE_URL         ?= https://github.com/coredns/coredns/archive/v1.10.0.tar.gz
PACKAGE_HEAD_URL           ?= https://github.com/coredns/coredns.git
PACKAGE_HEAD               ?= false
DEBUG                      ?= false

PROXY                      ?= socks5://10.0.0.131:10810
NO_PROXY                   ?= localhost,127.0.0.1,10.0.0.102:3000
USE_PROXY                  ?= false

# Golang
GO111MODULE                ?= on
GOPROXY                    ?= https://goproxy.cn,https://proxy.golang.com.cn,https://mirrors.aliyun.com/goproxy/,direct
GOSUMDB                    ?= off
GOPROXY_PRIVATE            ?= false
CGO_ENABLED                ?= 0
BUILD_FLAGS                ?= -v
BUILDPLATFORM              ?= linux/amd64
TARGETOS                   ?= linux
TARGETARCH                 ?= amd64
TARGETVARIANT              ?=

ifeq ($(GOPROXY_PRIVATE), true)
    GOPROXY                := http://10.0.0.102:3000
endif

VERSION                    ?= $(PACKAGE_VERSION)
# https://docs.brew.sh/Cask-Cookbook
# VERSION_MAJOR              := $(shell echo $(VERSION) | sed "s/^\([0-9]*\).*/\1/")
VERSION_MAJOR              := $(shell echo $(VERSION) | cut -f1 -d.)
# VERSION_MINOR              := $(shell echo $(VERSION) | sed "s/[0-9]*\.\([0-9]*\).*/\1/")
VERSION_MINOR              := $(shell echo $(VERSION) | cut -f2 -d.)
# VERSION_PATCH              := $(shell echo $(VERSION) | sed "s/[0-9]*\.[0-9]*\.\([0-9]*\).*/\1/")
VERSION_PATCH              := $(shell echo $(VERSION) | cut -f3 -d.)
VERSION_MAJOR_MINOR        := $(VERSION_MAJOR).$(VERSION_MINOR)

# COMMIT                     := $(shell git rev-parse HEAD)

# Docker
DOCKER_VERSION             := $(shell docker --version)

# CACHEBUST                  ?= $(date +%s)
# http://date.jsontest.com
# http://worldclockapi.com/api/json/utc/now
# https://api.github.com/repos/issenn/issenn/git/refs/heads/master
# https://timeapi.io/swagger/index.html
# http://worldtimeapi.org/pages/examples
# http://worldtimeapi.org/pages/schema
# https://timezoneapi.io
CACHEBUST                  ?= https://api.github.com/repos/$(AUTHOR)/docker-images-${PACKAGE_NAME}/git/refs/heads/master

ifeq ($(DEBUG), true)
    CACHEBUST              ?= http://date.jsontest.com
endif

DOCKER_BUILD_FLAGS         ?=

ifeq ($(USE_PROXY), true)
    DOCKER_BUILD_FLAGS     += --build-arg HTTP_PROXY="$(PROXY)" --build-arg HTTPS_PROXY="$(PROXY)" --build-arg NO_PROXY="$(NO_PROXY)"
endif

DOCKER_BUILD_NO_CACHE      ?= false
ifeq ($(DOCKER_BUILD_NO_CACHE), true)
    DOCKER_BUILD_FLAGS     += --no-cache=true --build-arg CACHEBUST="${CACHEBUST}"
endif

ifdef BUILDPLATFORM
    DOCKER_BUILD_FLAGS     += --build-arg BUILDPLATFORM=$(BUILDPLATFORM)
endif

ifdef TARGETOS
    DOCKER_BUILD_FLAGS     += --build-arg TARGETOS=$(TARGETOS)
endif

ifdef TARGETARCH
    DOCKER_BUILD_FLAGS     += --build-arg TARGETARCH=$(TARGETARCH)
endif

DOCKER_BUILDKIT            ?= true
BUILDKIT_PROGRESS          ?= auto  # auto / plain

# DOCKER_REGISTRY            ?= quay.io
IMAGE_NAME                 := $(PACKAGE_NAME)
IMAGE_PREFIX               ?= $(AUTHOR)
IMAGE_TAG                  ?= latest

ifdef DOCKER_REGISTRY
    REPOSITORY             := $(DOCKER_REGISTRY)/$(IMAGE_PREFIX)/$(IMAGE_NAME)
else
    REPOSITORY             := $(IMAGE_PREFIX)/$(IMAGE_NAME)
endif

LABEL                      ?= "Maintainer=Issenn <issenn@issenn.ml>"
PUSH_IMAGE                 ?= false
LATEST                     := latest

default: all
	@echo 'Run `make options` for a list of all options'

options: help
	@echo
	@echo 'Options:'
	@echo 'DOCKER = $(DOCKER_VERSION)'
    # @echo 'DOCDIR = $(DOCDIR)'
    # @echo 'DESTDIR = $(DESTDIR)'

help:
	@echo 'make:                 Test and compile.'
	@echo 'make clean:           Remove the compiled files'

all: build

.PHONY : debug
debug:
	env USE_PROXY=true BUILDKIT_PROGRESS=plain PACKAGE_HEAD=off GOPROXY_PRIVATE=true DOCKER_BUILD_NO_CACHE=true DEBUG=true make

build:
	env DOCKER_BUILDKIT=$(DOCKER_BUILDKIT) BUILDKIT_PROGRESS=$(BUILDKIT_PROGRESS) \
	    docker build -t $(REPOSITORY):$(IMAGE_TAG) $(DOCKER_BUILD_FLAGS) \
	        --label $(LABEL) \
	        --build-arg GO111MODULE="${GO111MODULE}" \
	        --build-arg GOPROXY="${GOPROXY}" \
	        --build-arg GOSUMDB="${GOSUMDB}" \
	        --build-arg CGO_ENABLED="${CGO_ENABLED}" \
	        --build-arg BUILD_FLAGS="${BUILD_FLAGS}" \
	        --build-arg PACKAGE_NAME="$(PACKAGE_NAME)" \
	        --build-arg PACKAGE_VERSION="$(PACKAGE_VERSION)" \
	        --build-arg PACKAGE_VERSION_PREFIX="$(PACKAGE_VERSION_PREFIX)" \
	        --build-arg PACKAGE_HEAD_URL="$(PACKAGE_HEAD_URL)" \
	        --build-arg PACKAGE_HEAD="$(PACKAGE_HEAD)" \
	        --build-arg PACKAGE_URL="$(PACKAGE_URL)" \
	        --build-arg PACKAGE_SOURCE_URL="$(PACKAGE_SOURCE_URL)" \
	        -f Dockerfile .

version:
	@docker run --rm -it $(REPOSITORY):$(IMAGE_TAG) --version

test:
	@docker run --rm -it $(REPOSITORY):$(IMAGE_TAG)

compile:

clean:
	@echo "Cleaning up..."

.PHONY : clean-docker-cache
clean-docker-cache:
	docker builder prune

.PHONY : clean-docker-cache-all
clean-docker-cache-all:
	docker builder prune

.PHONY : default options help all build version test compile clean
