ua() {
  if [[ $1 == setup ]]; then
    export API=${API:-https://openrouter.ai/api/v1/responses}
    export LOG=$(realpath -- "${2:-${LOG:-ua.log}}")
    export MODEL=${3:-${MODEL:-anthropic/claude-opus-4.6}}
    export SANDBOX=~/.config/ua/sandbox

    if [[ -z $KEY ]]; then
      if [[ -f ~/.config/secrets/openrouter ]]; then
        export KEY=$(< ~/.config/secrets/openrouter)
      else
        echo "~/.config/secrets/openrouter: No such file or directory" >&2
        return 1
      fi
    fi

    if [[ ! -f $LOG ]] && [[ -f ~/.config/ua/system.txt ]]; then
      command ua system < ~/.config/ua/system.txt
    fi

    echo "ua: using $MODEL with session log ${LOG/#$HOME\//\~\/}"
  else
    command ua "$@"
  fi
}
