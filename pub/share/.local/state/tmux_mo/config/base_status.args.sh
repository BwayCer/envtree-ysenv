#!/bin/env bash
# 輸出 tmux 設定命令

LEVEL=${1:-L1}   # (top) L1, L2, L3; (bottom) L8, L9

[[ "$LEVEL" =~ ^(L1|L2|L3|L8|L9)$ ]] || LEVEL="L1"


conf_g() {
  echo "set -g $1"
}

conf() {
  conf_g "$1"
}


## > 前導鍵 ---

# 舊式設定為 M-q, M-w, M-e
case "$LEVEL" in
  L1 ) conf_g "prefix M-h" ;;
  L2 ) conf_g "prefix M-j" ;;
  L3 ) conf_g "prefix M-k" ;;
  L8 ) conf_g "prefix C-h" ;;
  L9 ) conf_g "prefix C-l" ;;
esac


## > 狀態列 - 顏色 ---

conf_status_style() {
  conf "status-style fg=$1,bg=$2"
  conf "window-status-current-style fg=$2,bg=$1,bright"
}

case "$LEVEL" in
  L1 )
    conf_status_style "#37474F" "#B2DFDB"
    ;;
  L2 )
    conf_status_style "#37474F" "#80CBC4"
    ;;
  L3 )
    conf_status_style "#37474F" "#4DB6AC"
    ;;
  L8 )
    conf_status_style "#C5E1A5" "#00796B"
    ;;
  L9 )
    conf_status_style "#C5E1A5" "#1B5E20"
    ;;
esac


## > 狀態列 - 窗格 ---

case "$LEVEL" in
  L1 | L2 | L3 )
    # 窗格標籤風格
    conf "status-position top"
    conf "status-justify centre"

    # 窗格標籤格式
    conf 'window-status-current-format "| #I:#W#{?window_flags,#{window_flags}, } |"'

    # 窗格分隔線
    conf "pane-active-border-style fg=cyan"
    ;;
  L8 | L9 )
    # 窗格標籤風格
    conf "status-position bottom"
    conf "status-justify left"

    # 窗格分隔線
    conf "pane-active-border-style fg=green"
    ;;
esac


## > 狀態列 - 左側 ---

status_left_format='[#(tmux show-options -g | grep "^prefix " | sed "s/^prefix //")'
status_left_format+=":#S]   "
conf "status-left-length 10"
conf "status-left '${status_left_format}'"


## > 狀態列 - 右側 ---

status_right_format='@#{host} %H:%M '
# status_right_format+='#(ps o %%cpu= o %%mem= #{client_pid} | sed -e "s/^ *\([0-9.]\+\) *\([0-9.]\+\) *$/cpu=\1, mem=\2/g")'
conf "status-right '${status_right_format}'"
conf "status-right-length 40"
