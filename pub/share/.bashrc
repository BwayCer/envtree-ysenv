# ~/.bashrc for ys

# If not running interactively, don't do anything
# [[ $- != *i* ]] && return


## 簡單支持

alias ls='ls --color=auto'
alias ll="ls -al"
lt() { tree -CpugshD -I '.git/' "$@" | sed -E 's/(.+?── )?\[([^]]+)\]  (.+)/[\2] \1\3/'; }


## share 環境

the_path="~/.local/bin"
[[ ":$PATH:" =~ ":$the_path:" ]] || PATH="$PATH:$the_path"
unset the_path


if type PS777 &> /dev/null; then
  source PS777
elif [[ $EUID == 0 ]]; then
  PS1='\u@\h \W \$ '
else
  PS1='\u@\h \w \$ '
fi


## source .bashrc_* ##

ls "$HOME/.bashrc_"* &> /dev/null && {
  for rc_path in ~/.bashrc_*; do source "$rc_path"; done
  unset rc_path
} || :
