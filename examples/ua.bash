ua() {
  if [[ $# -eq 0 ]] && [[ ! -f $LOG ]]; then
    ua setup
  elif [[ $# -eq 0 ]]; then
    ua user && ua agent
  elif [[ $1 == setup ]]; then
    export API=${API:-https://openrouter.ai/api/v1/responses}
    export LOG=$(realpath -- "${2:-${LOG:-ua.log}}")
    export MODEL=${3:-${MODEL:-anthropic/claude-opus-4.6}}

    if [[ -z $KEY ]] && [[ -f ~/.config/secrets/openrouter ]]; then
      export KEY=$(< ~/.config/secrets/openrouter)
    fi

    if [[ -z $SANDBOX ]] && [[ -x ~/.config/ua/sandbox ]]; then
      export SANDBOX=~/.config/ua/sandbox
    fi

    if [[ ! -f $LOG ]] && [[ -f ~/.config/ua/system.txt ]]; then
      command ua system < ~/.config/ua/system.txt
    else
      touch "$LOG"
    fi

    echo "ua using $MODEL with session log ${LOG/#$HOME\//\~\/}"
  elif type rledit >/dev/null 2>&1; then
    VISUAL=${VISUAL:-${EDITOR:-vi}} EDITOR=rledit command ua "$@"
  else
    command ua "$@"
  fi
}
