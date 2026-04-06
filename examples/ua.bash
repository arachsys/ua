ua() (
  export API=${API:-https://openrouter.ai/api/v1/responses}
  export MODEL=${MODEL:-anthropic/claude-opus-4.6}

  if [[ ! -v KEY ]] && [[ -f ~/.config/secrets/openrouter ]]; then
    export KEY=$(< ~/.config/secrets/openrouter)
  fi

  if [[ -x ~/.config/ua/shell ]]; then
    export SHELL=~/.config/ua/shell
  fi

  if [[ ! -f ${LOG:-ua.log} ]] && [[ -f ~/.config/ua/system ]]; then
    command ua system < ~/.config/ua/system
  fi

  if [[ $* == chat ]]; then
    SHELL= exec ua
  else
    exec ua "$@"
  fi
)
