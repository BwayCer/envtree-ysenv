#!/bin/env bash

# $ bash <(curl -s https://raw.githubusercontent.com/BwayCer/envtree-ysenv/refs/heads/v1/install_sh/install.sh)

set -euo pipefail


## > 選項設定 ---

# PARENT of YS
# ├── MNT_YS_DIR
# │   └── envfile -> MNT_ENVFILE_DIR
# └── MNT_ENVFILE_DIR == {MNT_YS_DIR}_envfile
# HOME
# └── ys -> MNT_YS_DIR

mode="${1:-install-pm}"
case "$mode" in
  install-pm )
    ENVFILE_BRANCH="${2:-v1/main}"
    ENVYS_BRANCH="${3:-v1/pm-envys}"
    CONFIG_FROM_YS_PATH="${4:-config.yaml}"
    MAN_DIRNAME="${5:-pokemon}"

    MNT_YS_DIR="$HOME/ys"
    ;;
  init-pm )
    MNT_YS_DIR="$2"
    CONFIG_FROM_YS_PATH="${3:-config.yaml}"
    MAN_DIRNAME="${4:-pokemon}"
    ENVFILE_BRANCH="${5:-v1/main}"
    ENVYS_BRANCH="${6:-v1/pm-envys}"
    ;;
esac


MNT_ENVFILE_DIR="${MNT_YS_DIR}_envfile"
YS_DIR="$HOME/ys"
YS_ENVFILE_DIR="$YS_DIR/envfile"
YS_MAN_DIR="$YS_DIR/$MAN_DIRNAME"

YSENV_CONFIG_PATH="$YS_DIR/$CONFIG_FROM_YS_PATH"


## > 實用函式 - tell_cmd ---

HAS_CREATE_ENV_ACTION=false

tell_cmd() {
  HAS_CREATE_ENV_ACTION=true
  echo "\$ $@"; "$@"
}


## > 實用函式 - sudo ---

IS_SUDO=false
if [[ "$EUID" -ne 0 ]]; then
  if command -v sudo &> /dev/null; then
    IS_SUDO=true
  else
    echo "請安裝 sudo 命令." >&2
    exit 1
  fi
fi

sudoo() {
  $IS_SUDO && tell_cmd sudo "$@" || tell_cmd "$@"
}


## > 實用函式 ---

git_download() {
  local git_account="$1"
  local git_branch="$2"
  local target="$3"

  local git_zip_url="https://github.com/$git_account/archive/refs/heads/$git_branch.zip"

  local parent_dir="$(dirname "$target")"
  [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"

  curl -kL "$git_zip_url" -o "$target.zip"
  unzip -q "$target.zip" -d "$target.wrap"
  mv "$target.wrap"/* "$target"
  [[ $? -eq 0 ]] && {
    rm -rf "$target.zip" "$target.wrap"
  } || :
}

check_ln_path() {
  local target_path="$1"
  local ln_path="$2"

  if [[ -e "$ln_path" ]]; then
    [[ -L "$ln_path" && "$(realpath "$ln_path")" == "$target_path" ]] || {
      echo "請移除 \"$ln_path\" 後重新執行." >&2
      exit 1
    }
  fi
}


## > 安裝環境 ---

# 適用系統: debian arch
# 需求命令: curl unzip
install_pkgs() {
  local sys_id_like="unknow"
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release

    case "${ID_LIKE:-$ID}" in
      debian | arch )
        sys_id_like="${ID_LIKE:-$ID}"
        ;;
    esac
  fi

  local cmd
  local need_cmds=(curl unzip)
  local missing_cmds=()
  local need_pkgs=()
  for cmd in "${need_cmds[@]}"; do
    command -v "$cmd" &>/dev/null && continue || :

    case "${sys_id_like}:$cmd" in
      debian:curl | arch:curl )
        need_pkgs+=(curl)
        ;;
      debian:unzip | arch:unzip )
        need_pkgs+=(unzip)
        ;;
      * )
        missing_cmds=($cmd)
        ;;
    esac
  done

  if [[ ${#need_pkgs[@]} -gt 0 ]]; then
    if [[ ${#missing_cmds[@]} -gt 0 ]]; then
      echo "請安裝 ${missing_cmds[*]} 命令." >&2
      exit 1
    fi

    case "$sys_id_like" in
      debian )
        sudoo apt install "${need_pkgs[@]}"
        ;;
      arch )
        sudoo pacman -S "${need_pkgs[@]}"
        ;;
    esac
  fi
}
install_pkgs


## > ---

check_ln_path "$MNT_ENVFILE_DIR" "$YS_ENVFILE_DIR"

[[ -e "$YS_DIR" || -e "$MNT_YS_DIR" ]] ||
  tell_cmd git_download "BwayCer/envtree-ysenv" "$ENVYS_BRANCH" "$MNT_YS_DIR"
[[ -e "$YS_ENVFILE_DIR" || -e "$MNT_ENVFILE_DIR" ]] ||
  tell_cmd git_download "BwayCer/envtree-ysenv" "$ENVFILE_BRANCH" "$MNT_ENVFILE_DIR"

[[ -e "$YS_DIR" ]] ||
  tell_cmd ln -sfn "$MNT_YS_DIR" "$YS_DIR"
[[ -e "$YS_ENVFILE_DIR" ]] ||
  tell_cmd ln -sfn "$MNT_ENVFILE_DIR" "$YS_ENVFILE_DIR"
[[ -e "$YS_MAN_DIR" ]] ||
  tell_cmd mkdir -p "$YS_MAN_DIR"

$HAS_CREATE_ENV_ACTION && echo -e "\n---\n" || :

# init ysenv
export YSENV_CONFIG_PATH="$YSENV_CONFIG_PATH"
"$YS_ENVFILE_DIR/init.sh"
