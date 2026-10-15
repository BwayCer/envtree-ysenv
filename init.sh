#!/bin/env bash

set -euo pipefail

FILEPATH=`realpath "$0"`
DIRNAME=`dirname "$FILEPATH"`

MNT_YS_DIR="$DIRNAME"

bash <(curl -s https://raw.githubusercontent.com/BwayCer/envtree-ysenv/refs/heads/v1/install_sh/install.sh) \
  "init-pm" \
  "$MNT_YS_DIR" \
  "config.yaml" \
  "pokemon" \
  "v1/main" \
  "v1/pm-envys"
