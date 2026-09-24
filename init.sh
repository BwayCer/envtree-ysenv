#!/bin/env bash

set -euo pipefail

FILEPATH=`realpath "$0"`
DIRNAME=`dirname "$FILEPATH"`

ENVFILE_DIR="$DIRNAME"
YSENV_DIR="$ENVFILE_DIR/pub/ysenv"
YSSHARE_DIR="$ENVFILE_DIR/pub/share"

HAS_CREATE_ENV_ACTION=false

tell_cmd() {
  HAS_CREATE_ENV_ACTION=true
  echo "\$ $@"; "$@"
}


## > 檢查環境 ---

tmp_file_path="$YSENV_DIR/.local/bin/ysenv"
[[ -f "$tmp_file_path" ]] || {
  echo "找不到 \"$tmp_file_path\" 文件." >&2
  exit 1
}
[[ -x "$tmp_file_path" ]] || {
  echo "未把 \"$tmp_file_path\" 設定為執行文件." >&2
  exit 1
}


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
  $IS_SUDO && sudo "$@" || "$@"
}


if ! python3 -c "import yaml" &> /dev/null; then
  has_install=false

  if [[ -f /etc/os-release ]]; then
    . /etc/os-release

    case "${ID_LIKE:-$ID}" in
      debian )
        echo "\$ sudo apt update && sudo apt install python3-yaml"
        sudoo apt update
        sudoo apt install python3-yaml
        has_install=true
        ;;
      arch )
        echo "\$ sudo pacman -S python-yaml"
        sudoo pacman -S python-yaml
        has_install=true
        ;;
    esac
  fi

  HAS_CREATE_ENV_ACTION=$has_install
  $has_install || {
    echo "請安裝 PyYAML 套件庫." >&2
    exit 1
  }
fi


## > 建立環境 ---

$HAS_CREATE_ENV_ACTION && echo -e "\n---\n" || :
HAS_CREATE_ENV_ACTION=false

ln_ysenv() {
  local target_part="$1"

  local src="$YSENV_DIR/$target_part"
  local target="$HOME/$target_part"

  [[ -f "$target" && "$(realpath "$target")" == "$src" ]] && return || :

  HAS_CREATE_ENV_ACTION=true

  local parent_dir="$(dirname "$target")"
  [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"

  echo "\$ ln -sfn (%s: $target_part) $YSENV_DIR/%s $HOME/%s"
  ln -sfn "$src" "$target"
}

ln_ysenv .local/bin/ysenv
ln_ysenv .local/share/bash-completion/completions/ysenv.bash

# 停頓用以看是否有動作被執行
$HAS_CREATE_ENV_ACTION && sleep 1 || :


## > 以 ysenv 建立環境 ---

PATH="$PATH:$HOME/.local/bin"

if [[ " $(ysenv list host 2> /dev/null) " =~ " tty " ]]; then
  $HAS_CREATE_ENV_ACTION && echo -e "\n---\n" || :
  HAS_CREATE_ENV_ACTION=false

  for file in .bashrc .bash_profile .profile; do
    [[ -f "$HOME/$file" &&
        -f "$YSSHARE_DIR/$file" &&
        ! -L "$HOME/$file" ]] &&
      tell_cmd mv "$HOME/$file" "$HOME/.os_orig$file" || :
  done

  $HAS_CREATE_ENV_ACTION && echo -e "\n---\n" || :
  HAS_CREATE_ENV_ACTION=true

  ysenv host tty
fi


## > 提示 ---

$HAS_CREATE_ENV_ACTION && echo -e "\n---\n" || :

echo "請執行 \`source ~/.bashrc\`"

[[ -n "$YSENV_CONFIG_PATH" ]] &&
  echo "請執行 \`export YSENV_CONFIG_PATH=\"$YSENV_CONFIG_PATH\"\`" || :
