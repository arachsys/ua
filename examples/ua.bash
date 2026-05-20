ua() (
  export API=${API:-https://openrouter.ai/api/v1/responses}
  export MODEL=${MODEL:-anthropic/claude-opus-4.7}

  if [[ ! -v KEY ]] && [[ -f ~/.config/secrets/openrouter ]]; then
    export KEY=$(< ~/.config/secrets/openrouter)
  fi

  if [[ -x ~/.config/ua/shell ]]; then
    export SHELL=~/.config/ua/shell
  fi

  if [[ ! -f ${LOG:-ua.log} ]] && [[ -f ~/.config/ua/system ]]; then
    command ua system < ~/.config/ua/system
  fi

  if [[ $# -eq 0 ]] && type rledit >/dev/null 2>&1; then
    export EDITOR=rledit VISUAL=${VISUAL:-${EDITOR:-vi}}
    while command ua user && echo && command ua agent; do
      continue
    done
  else
    exec ua "$@"
  fi
)
