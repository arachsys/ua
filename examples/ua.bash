ua() (
  export API=${API:-https://openrouter.ai/api/v1/responses}
  export MODEL=${MODEL:-anthropic/claude-opus-4.6}

  if [[ ! -v KEY ]] && [[ -f ~/.config/secrets/openrouter ]]; then
    export KEY=$(< ~/.config/secrets/openrouter)
  fi

  if [[ ! -v SANDBOX ]] && [[ -x ~/.config/ua/sandbox ]]; then
    export SANDBOX=~/.config/ua/sandbox
  fi

  if [[ ! -f ${LOG:-ua.log} ]] && [[ -f ~/.config/ua/system ]]; then
    command ua system < ~/.config/ua/system
  fi

  if [[ $* == chat ]]; then
    export -n SANDBOX
    exec ua
  else
    exec ua "$@"
  fi
)
