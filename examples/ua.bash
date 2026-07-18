ua() {
  case "$1" in
    abort | agent | recap | system | user)
      (
        export API=https://openrouter.ai/api/v1/responses
        export KEY=$(< ~/.config/secrets/openrouter)
        export SHELL=~/.config/ua/sandbox
        export LOG MODEL REASONING TOOLS

        if [[ $# -gt 1 ]] && ! ua anchor "${@:2}"; then
          exit 1
        elif ! cd -- "$ANCHOR" 2>/dev/null; then
          echo 'ua: Not anchored in a valid directory' >&2
          exit 1
        elif [[ -z $LOG ]] || [[ ! -d $(dirname "$LOG") ]]; then
          echo 'ua: Not anchored to a valid log file' >&2
          exit 1
        fi

        if [[ $1 == recap ]] && [[ ! -f $LOG ]]; then
          echo "ua: $LOG not found" >&2
          exit 1
        elif [[ $1 == recap ]] && [[ -t 1 ]]; then
          command ua recap | sed -E -e 's/^> ?(.*)/\c[[32m\1\c[[0m/' \
            -e 's/^\| ?(.*)/\c[[34m\1\c[[0m/' -e 's/^< ?//'
          exit ${PIPESTATUS[0]}
        elif [[ $1 == user ]] && [[ ! -s $LOG ]]; then
          find -L ~/.config/ua/system -type f -print0 \
              | while IFS= read -d '' -r FILE; do
            command ua system < "$FILE"
          done 2>/dev/null
        fi

        exec ua "$1"
      )
      ;;

    anchor)
      if [[ $# -eq 1 ]]; then
        echo "Directory is ${ANCHOR-not set}"
        echo "Log file is ${LOG-not set}"
      elif [[ $# -eq 2 ]] && [[ -d $2 ]]; then
        ANCHOR=$(realpath -m "$2") && LOG=$ANCHOR/ua.log
      elif [[ $# -eq 2 ]] && [[ -d $(dirname "$2") ]]; then
        LOG=$(realpath -m "$2") && ANCHOR=$(dirname "$LOG")
      elif [[ $# -ge 3 ]] && [[ -d $2 ]]; then
        ANCHOR=$(realpath -m "$2") && LOG=$(realpath -m "$3")
      else
        echo "ua: $2 is not a directory or log file" >&2
        return 1
      fi
      ;;

    model)
      if [[ $# -eq 1 ]]; then
        echo "Model is ${MODEL-not set}"
        echo "Reasoning is ${REASONING-not set}"
      elif [[ $# -eq 2 ]]; then
        MODEL=$2 && unset REASONING
      elif [[ $# -ge 3 ]]; then
        MODEL=$2 && REASONING=$3
      fi
      ;;

    reset)
      unset ANCHOR LOG MODEL REASONING
      ;;

    scratch)
      ANCHOR=$(mktemp -d --tmpdir ua.XXXXXX) \
        && ua anchor "$ANCHOR" "${@:2}" \
        && printf '%s\n' "$ANCHOR"
      ;;

    *)
      cat >&2 <<EOF
Usage:
  ua abort                      abort all pending function calls
  ua agent                      request a response from the model
  ua anchor [DIR] [LOG]         anchor agent in DIR and log to LOG
  ua model [MODEL] [EFFORT]     set the model and reasoning effort
  ua recap                      print the conversation history
  ua reset                      unset anchor, log, model and reasoning
  ua scratch [LOG]              anchor agent inside a scratch directory
  ua system                     add a system message to the conversation
  ua user                       add a user message to the conversation

Bindings:
  C-j, S-RET    insert a literal newline into the input text
  M-a, M-A      send input to the agent instead of the shell
EOF
      return 64
      ;;
  esac
}

if [[ -v PS1 ]]; then
  readline-agent() {
    local HIGHLIGHT STATE=$(stty -g)
    if [[ $READLINE_LINE == *([[:space:]]) ]]; then
      READLINE_LINE=
      ua agent
    elif ua "${1:-user}" <<< "$READLINE_LINE"; then
      HIGHLIGHT=34 && [[ $1 == ?(user) ]] && HIGHLIGHT=32
      printf '\e[%sm%s\e[0m\n\n' "$HIGHLIGHT" "$READLINE_LINE"
      READLINE_LINE=
      ua agent
    fi
    stty "$STATE"
  }

  readline-edit() {
    local STATE=$(stty -g) TMP
    if TMP=$(mktemp --tmpdir bash-fc.XXXXXX); then
      printf '%s\n' "$READLINE_LINE" >"$TMP"
      eval "${FCEDIT:-${EDITOR:-vi}}" "${TMP@Q}"
      if [[ $? -ne 148 ]]; then
        READLINE_LINE=$(< "$TMP")
        READLINE_POINT=${#READLINE_LINE}
        rm -f -- "$TMP"
      else
        READLINE_LINE=
      fi
    fi
    stty "$STATE"
  }

  bind '"\C-j": "\C-v\C-j"'
  bind '"\e[27;2;13~": "\C-v\C-j"'
  bind -x '"\ea": readline-agent user'
  bind -x '"\eA": readline-agent system'
  bind -x '"\C-x\C-e": readline-edit'
fi
