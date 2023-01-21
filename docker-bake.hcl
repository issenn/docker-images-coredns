variable "TAG" {
  default = "latest"
}

variable "DOCKER_BUILDKIT" {
  default = true
}

variable "BUILDKIT_PROGRESS" {
  default = "auto"
}

variable "CACHEBUST" {
  default = 0
}

variable "PACKAGE_VERSION" {
  default = ""
}

variable "PACKAGE_VERSION_PREFIX" {
  default = ""
}

variable "PACKAGE_HEAD" {
  default = false
}

variable "GO111MODULE" {
  default = "on"
}

variable "GOPROXY" {
  default = "https://proxy.golang.org,direct,direct"
}

variable "GOPROXY_CN" {
  default = "http://10.0.0.102:3000,https://goproxy.cn,https://proxy.golang.com.cn,https://mirrors.aliyun.com/goproxy/,direct"
}

variable "GOSUMDB" {
  default = "sum.golang.org"
}

variable "GOSUMDB_CN" {
  default = "sum.golang.google.cn"
  // default = "gosum.io+ce6e7565+AY5qEHUk/qmHc5btzW45JVoENfazw8LielDsaI+lEbq6"
}

variable "CGO_ENABLED" {
  default = 0
}

variable "BUILD_FLAGS" {
  default = "-v"
}

group "default" {
  targets = [
    "main",
    // "other",
    // "darwin",
  ]
}

target "main" {
  dockerfile = "Dockerfile"
  platforms = [
    "linux/386",
    "linux/amd64",
    "linux/arm/v6",
    "linux/arm/v7",
    "linux/arm64",
    "linux/mips64",
    "linux/mips64le",
    "linux/ppc64le",
    "linux/s390x",
    "linux/riscv64",
  ]
  args = {
    PACKAGE_NAME = "coredns"
    PACKAGE_VERSION = "1.10.0"
    PACKAGE_VERSION_PREFIX = PACKAGE_VERSION_PREFIX
    PACKAGE_URL = "https://github.com/coredns/coredns"
    PACKAGE_SOURCE_URL = "https://github.com/coredns/coredns/archive/v1.10.0.tar.gz"
    PACKAGE_HEAD_URL = "https://github.com/coredns/coredns.git"
    PACKAGE_HEAD = PACKAGE_HEAD
    CACHEBUST = "https://api.github.com/repos/issenn/docker-images-coredns/git/refs/heads/master"
    GO111MODULE = GO111MODULE
    GOPROXY = GOPROXY
    GOSUMDB = GOSUMDB
    CGO_ENABLED = CGO_ENABLED
    BUILD_FLAGS = BUILD_FLAGS
  }
}

target "darwin" {
  platforms = [
    "darwin/amd64",
    // "darwin/arm",
    "darwin/arm64",
  ]
  inherits = [
    "main"
  ]
}

target "other" {
  platforms = [
    // "linux/arm",
    // "linux/arm64/v8",
    "linux/mips",
    "linux/mipsle",
    "linux/ppc64",
  ]
  inherits = [
    "main"
  ]
}

target "android" {
  platforms = [
    "android/386",
    "android/amd64",
    "android/arm",
    "android/arm64",
  ]
}
