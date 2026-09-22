
#---
# #$ tmux.mo
# @ --show --help
# @ default.conf base_status.args.sh
# @ L1 L2 L3 L8 L9
# @ list_style
# @ list_config -g -s -w --help
#---


__complete_tmux_mo() {
  local cur prev words cword
  _init_completion 2> /dev/null || {
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
  }

  _which_cmd() {
    local cmd=""
    local has_flag=false
    local idx
    for (( idx=1; idx < COMP_CWORD; idx++ )); do
      local word="${COMP_WORDS[idx]}"

      if [[ "$word" == -* ]]; then
        has_flag=true
        break
      fi

      cmd+="__c:${word}"
    done

    [[ -z "$cmd" ]] && cmd="main" || cmd="${cmd:2}"

    # 有旗標 (`--`, `-*`, `--*`) 則不會在是子命令
    $has_flag && cmd+="__hf" || cmd+="__nf"

    [[ "$cur" == -* ]] && cmd+="__flag" || cmd+="__var"

    echo "$cmd"
  }

  # 輸入 `_get_long_flags "-j:--json -y:--yaml --help"`.
  # 返回 "--json --yaml --help"
  _get_long_flags() {
    local raw_opts="$1"

    local item
    local answer_opts=""
    # 逐一取出空白分隔的項目
    for item in $raw_opts; do
      if [[ "$item" == *:* ]]; then
        # 遇到 "短:長" 格式裁掉冒號與左邊的短選項
        answer_opts+=" ${item#*:}"
      else
        answer_opts+=" $item"
      fi
    done

    # 裁掉最前方的空白後輸出
    echo "${answer_opts:1}"
  }

  # 過濾已在命令列中出現過的 flag
  # - 輸入 `_filter_used_flags "-j:--json -y:--yaml --help"`.
  # - 若已輸入 `-y` 會捕獲到 `-y:--yaml` 並將其移除;
  #   若已輸入 `--yaml` 會捕獲到 `-y:--yaml` 並將其移除.
  # - 不可以沒有長選項.
  _filter_used_flags() {
    local raw_opts="$1"

    local word
    local pattern_sort pattern_long
    local answer_opts="$raw_opts"
    for word in "${COMP_WORDS[@]}"; do
      pattern_sort=" ($word:--[A-Za-z]+) "
      pattern_long=" ((-[A-Za-z]:)?$word) "

      if [[ " $answer_opts " =~ $pattern_sort || " $answer_opts " =~ $pattern_long ]]; then
        match="${BASH_REMATCH[1]}"
        answer_opts="${answer_opts//$match/ }"
      fi
    done

    echo $answer_opts
  }

  # 過濾已在命令列中出現過的 var
  _filter_used_vars() {
    local raw_opts="$1"

    local word
    local answer_opts="$raw_opts"
    for word in "${COMP_WORDS[@]}"; do
      pattern=" ($word) "
      if [[ " $answer_opts " =~ $pattern ]]; then
        match="${BASH_REMATCH[1]}"
        answer_opts="${answer_opts//$match/ }"
      fi
    done

    echo $answer_opts
  }

  local cmd=$(_which_cmd)
  case "$cmd" in
    c:list_style__* ) ;;

    c:list_config__*__flag )
      local options="-g -s -w -h:--help"
      local available_opts="$(_get_long_flags "$(_filter_used_flags "$options")")"
      COMPREPLY=( $(compgen -W "$available_opts" -- "$cur") )
      ;;

    c:list_config__* ) ;;

    main__*__flag )
      local options="-s:--show -h:--help"
      local available_opts="$(_get_long_flags "$(_filter_used_flags "$options")")"
      COMPREPLY=( $(compgen -W "$available_opts" -- "$cur") )
      return 0
      ;;

    c:*__var )
      [[ "$cmd" =~ \.(sh|conf) ]] || return 0

      local options="default.conf base_status.args.sh"
      local available_opts="$(_filter_used_vars "$options")"
      COMPREPLY=( $(compgen -W "$available_opts" -- "$cur") )
      return 0
      ;;

    main__*__* )
      local subcommands="list_style list_config"
      local options="$subcommands L1 L2 L3 L8 L9 default.conf base_status.args.sh"
      COMPREPLY=( $(compgen -W "$options" -- "$cur") )
      return 0
      ;;
  esac
}

complete -F "__complete_tmux_mo" "tmux_mo"
