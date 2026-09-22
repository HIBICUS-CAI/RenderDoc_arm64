#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential \
  gcc-14 \
  g++-14 \
  cmake \
  pkg-config \
  curl \
  xz-utils \
  libx11-dev \
  libx11-xcb-dev \
  libxext-dev \
  libxi-dev \
  libxrender-dev \
  libxcb1-dev \
  libxcb-util-dev \
  libxcb-keysyms1-dev \
  libxcb-image0-dev \
  libxcb-shm0-dev \
  libxcb-icccm4-dev \
  libxcb-sync-dev \
  libxcb-xfixes0-dev \
  libxcb-shape0-dev \
  libxcb-randr0-dev \
  libxcb-render0-dev \
  libxcb-render-util0-dev \
  libxcb-xinerama0-dev \
  libxcb-xinput-dev \
  libxcb-xkb-dev \
  libxkbcommon-dev \
  libxkbcommon-x11-dev \
  libfontconfig1-dev \
  libfreetype-dev \
  libssl-dev \
  mesa-common-dev \
  libgl1-mesa-dev \
  zlib1g-dev \
  libbz2-dev \
  libffi-dev \
  liblzma-dev \
  libsqlite3-dev \
  libreadline-dev \
  libncurses-dev \
  libgdbm-dev \
  libgdbm-compat-dev \
  uuid-dev \
  libzstd-dev \
  bison \
  autoconf \
  automake \
  libtool
