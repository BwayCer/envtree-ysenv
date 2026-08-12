_ysenv() {
  local curr prev words cword
  _init_completion 2> /dev/null || {
    curr="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD - 1]}"
  }

  _whichCmd() {
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

    [[ "$curr" == -* ]] && cmd+="__flag" || cmd+="__var"

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

  local cmd=$(_whichCmd)

  local bool_flags=""
  local val_flags=""
  local multi_val_flags="--forklift"
  local bool_flags_for_cntr="--daemon --pwdir"
  local val_flags_for_cntr="--name --vmhome --workdir --image"

  # --read-only: 將容器的根檔案系統掛載為唯讀。
  # --init: 在容器內執行一個 init 進程（如 `tini`）來轉發信號並收割孤兒進程。
  # --no-healthcheck: 停用鏡像中定義的健康檢查。
  local bool_flags_for_oci="--rm -i:--interactive -t:--tty -d:--detach --privileged --read-only --init --no-healthcheck"

  # --restart <string>: 指定重啟策略（如 `no`, `on-failure`, `always`, `unless-stopped`）。
  # --network <string>: 指定容器連接的網路（如 `bridge`, `host`, `none` 或自訂網路名稱）。
  # --ip <string>: 指定容器的靜態 IPv4 地址。
  # --pid <string>: 指定 PID 命名空間模式（如 `host`）。
  # --ipc <string>: 指定 IPC 命名空間模式（如 `host`）。
  # --uts <string>: 指定 UTS 命名空間模式（如 `host`）。
  # --cgroupns <string>: 指定 Cgroup 命名空間模式（如 `private`, `host`）。
  # --stop-signal <string>: 指定停止容器時發送的信號（預設為 `SIGTERM`）。
  # --stop-timeout <int>: 指定停止容器的超時等待秒數。
  # --cpus <decimal>: 限制容器可使用的 CPU 核心數量。
  # -m:--memory <string>: 限制容器可使用的記憶體大小（如 `512m`, `2g`）。
  # --shm-size <string>: 設定 `/dev/shm` 共享記憶體的大小。
  local val_flags_for_oci="--name -w:--workdir -u:--user --entrypoint --hostname --restart --network --ip --pid --ipc --uts --cgroupns --stop-signal --stop-timeout --cpus -m:--memory --shm-size"

  # --oom-kill-disable: 防止 OOM Killer 殺死該容器（需配合 `-m` 使用）。
  # --sig-proxy: 將所有發送到 `run` 命令的信號轉發給容器進程（預設為 true，可用於控制信號行為）。
  # local multi_bool_flags_for_oci="--oom-kill-disable --sig-proxy"

  # -e:--env <key=value>: 設定容器內的前景環境變數。
  # --env-file <file>: 從指定檔案讀取環境變數清單。
  # -v:--volume <src:dst[:opts]>: 掛載宿主機目錄或卷至容器內。
  # --mount <type=...,src=...,dst=...>: 更詳細地指定掛載類型與設定（bind, volume, tmpfs）。
  # -p:--publish <host_port:container_port>: 將容器端口映射發布至宿主機。
  # -l:--label <key=value>: 為容器附加元資料（Metadata/Label）。
  # --add-host <host:ip>: 向容器內的 `/etc/hosts` 強行添加映射紀錄。
  # --dns <ip>: 指定容器自訂的 DNS 伺服器地址。
  # --dns-search <domain>: 指定容器自訂的 DNS 搜尋網域。
  # --dns-opt <option>: 指定容器自訂的 DNS 選項。
  # --device <host-dev:container-dev>: 將宿主機的硬體設備映射至容器內。
  # --cap-add <capability>: 為容器新增指定的 Linux Capability 特權（如 `NET_ADMIN`）。
  # --cap-drop <capability>: 移除容器指定的 Linux Capability 特權（如 `SYS_ADMIN`）。
  # --security-opt <option>: 自訂安全模組設定（如 `seccomp=...`, `apparmor=...`, `label=...`）。
  # --ulimit <type=soft:hard>: 覆蓋容器的 Ulimit 限制（如 `nofile=1024:2048`）。
  # --group-add <group>: 為容器內執行進程的使用者添加額外的 Linux 組（Group）。
  local multi_val_flags_for_oci="-e:--env --env-file -v:--volume --mount -p:--publish -l:--label --add-host --dns --dns-search --dns-opt --device --cap-add --cap-drop --security-opt --ulimit --group-add "


  local not_complete_path_flag_for_custom=""
  local not_complete_path_flag_for_oci="--name -u:--user"

  case "$cmd" in
    main__*__flag )
      local subcommands="--help"
      COMPREPLY=( $(compgen -W "${subcommands}" -- "$curr") )
      return 0
      ;;

    main__hf__* ) ;;

    main__* )
      local subcommands="edit list host cntr"
      COMPREPLY=( $(compgen -W "${subcommands}" -- "$curr") )
      return 0
      ;;

    c:list__*__var )
      if [[ $COMP_CWORD -ge 3 ]]; then
        return 0
      fi

      local argus="pallet host cntr"
      COMPREPLY=( $(compgen -W "${argus}" -- "$curr") )
      ;;

    c:host__*__*__flag | c:cntr__*__*__flag )
      local default_opts default_multi_opts

      case "$cmd" in
        c:host__* )
          default_opts="$bool_flags $val_flags $bool_flags_for_oci $val_flags_for_oci"
          default_multi_opts="$multi_val_flags $multi_val_flags_for_oci"
          ;;

        c:cntr__* )
          default_opts="$bool_flags $val_flags $bool_flags_for_cntr $val_flags_for_cntr $bool_flags_for_oci $val_flags_for_oci"
          default_multi_opts="$multi_val_flags $multi_val_flags_for_oci"
          ;;
      esac

      # 過濾已使用的 flag
      local available_opts=$(_get_long_flags "$(_filter_used_flags "$default_opts") $default_multi_opts")

      COMPREPLY=( $(compgen -W "$available_opts" -- "$curr") )
      ;;

    c:host__*__*__var | c:cntr__*__*__var )
      local not_complete_path_flag=""

      case "$cmd" in
        # c:host__* )
          # not_complete_path_flag=" "
          # ;;

        c:cntr__* )
          not_complete_path_flag=" $bool_flags_for_cntr"
          ;;
      esac

      not_complete_path_flag+=" $bool_flags $not_complete_path_flag_for_custom"
      not_complete_path_flag+=" $bool_flags_for_oci $not_complete_path_flag_for_oci"

      # 處理帶參數 flag 的補全
      if [[ "$prev" == "--forklift" ]]; then
        local pallet_boxs=$(ysenv list pallet 2> /dev/null)
        COMPREPLY=( $(compgen -W "$pallet_boxs" -- "$curr") )
        return 0
      elif [[ "$prev" == "--image" ]]; then
        local cmdList=(
          $(ysenv cntrCommand)
          images
          --filter "dangling=false"
          --format "{{.Repository}}:{{.Tag}}"
        )
        local images=$("${cmdList[@]}" 2> /dev/null)
        COMPREPLY=( $(compgen -W "$images" -- "$curr") )
        return 0
      fi

      # 預設提供路徑補全
      if [[ " ${not_complete_path_flag//:/ } " != *" $prev "* ]]; then
        compopt -o nospace -o filenames 2> /dev/null
        COMPREPLY=( $(compgen -f -- "$curr") )
      fi
      ;;

    c:host__*__var | c:cntr__*__var )
      local pallet_boxs

      case "$cmd" in
        c:host__* )
          pallet_boxs=$(ysenv list host 2> /dev/null)
          ;;

        c:cntr__* )
          pallet_boxs=$(ysenv list cntr 2> /dev/null)
          ;;
      esac

      COMPREPLY=( $(compgen -W "$pallet_boxs" -- "$curr") )
      ;;
  esac
}

complete -F _ysenv ysenv
