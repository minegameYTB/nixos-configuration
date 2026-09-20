# configurations/modules/misc/auto-update/output.nix — status messages,
# output rendering and persistent logging for the auto-update services.
#
# Split (PATH-hygiene: tiny services must not drag the nom/sed closure):
#   core   — _init_output, _status, _write_state (coreutils + builtins only)
#   render — _monitor_nix_output (nom), _filter_git_progress (sed),
#            _prefix_lines (prefixes a stream via _status)
#   full   — core + render (main service only)
#
# All substantive output flows through _status (fd 5 -> journal with the
# service PID, plus $LOG_FILE append): a single PID per run in the journal.
#
# Callers must set before use: LOG_FILE, STATE_DIR (+
# STATUS_LOGGING_ENABLED, INTERACTIVE_OUTPUT via _init_output).
{ }:

let
  core = ''
    # >>>BEGIN output-core
    _init_output() {
      STATUS_LOGGING_ENABLED=0

    # Status messages go to fd 5 (-> journal stderr) so they stay under
    # the service PID with their [LEVEL] prefix.
    exec 5>&2

      INTERACTIVE_OUTPUT=0
      if [ -t 1 ] || [ -t 2 ] || ( : <> /dev/tty ) 2>/dev/null; then
        INTERACTIVE_OUTPUT=1
      fi

      AUTO_UPDATE_NIX_LOG_FORMAT="raw"
      INFO_PREFIX="[INFO]"
      WARNING_PREFIX="[WARNING]"
      ERROR_PREFIX="[ERROR]"
      WAIT_PREFIX="[WAIT]"
      if [ "$INTERACTIVE_OUTPUT" -eq 1 ]; then
        AUTO_UPDATE_NIX_LOG_FORMAT="internal-json"
        INFO_PREFIX=$'\033[1;36m[INFO]\033[0m'
        WARNING_PREFIX=$'\033[1;33m[WARNING]\033[0m'
        ERROR_PREFIX=$'\033[1;31m[ERROR]\033[0m'
        WAIT_PREFIX=$'\033[1;35m[WAIT]\033[0m'
      fi
    }

    _status() {
      local level="$1"
      local prefix
      shift

      case "$level" in
        INFO) prefix="$INFO_PREFIX" ;;
        WARNING) prefix="$WARNING_PREFIX" ;;
        ERROR) prefix="$ERROR_PREFIX" ;;
        WAIT) prefix="$WAIT_PREFIX" ;;
        *) prefix="[$level]" ;;
      esac
      printf '%b %s\n' "$prefix" "$*" >&5
      if [ "$STATUS_LOGGING_ENABLED" -eq 1 ]; then
        printf '[%s] %s\n' "$level" "$*" >> "$LOG_FILE" || true
      fi
    }

    _write_state() {
      local state_value="$1"
      local state_tmp

      state_tmp=$(mktemp "$STATE_DIR/.state.XXXXXX")
      printf '%s\n' "$state_value" > "$state_tmp"
      chmod 0644 "$state_tmp"
      mv -f -- "$state_tmp" "$STATE_FILE"
      sync -f "$STATE_DIR" || true
    }
    # <<<END output-core
  '';

  render = ''
    # >>>BEGIN output-render
    _monitor_nix_output() {
      if [ "$INTERACTIVE_OUTPUT" -eq 1 ]; then
        # The dynamic nom graph stays on the terminal only: its redraws would
        # make the persistent log unreadable.
        TERM="''${TERM:-xterm-256color}" \
          nom --json > /dev/tty 2>&1
      else
        # Headless: keep the raw, concise nix output.
        cat
      fi
    }

    _filter_git_progress() {
      # Drop the language-independent percentage/counter format.
      sed -u -E \
        -e '/remote: (Enumerating objects:|Counting objects:|Compressing objects:|Total [0-9])/d' \
        -e '/[[:space:]][0-9]+% \([0-9]+\/[0-9]+\)(,.*)?$/d'
    }

    _prefix_lines() {
      # Prefix a streamed command output via _status: uniform [LEVEL] lines
      # under the service PID in both journal and $LOG_FILE. Runs in a
      # pipeline subshell (logging only — exit status intentionally ignored
      # by callers, pipefail still reports the producer's failure).
      # ANSI control sequences would pollute both sinks (nom renders to
      # /dev/tty directly and never flows here); a single sed strips them
      # for the whole stream (bash glob classes like [0-9]* misbehave here,
      # eating entire lines — sed BRE does not).
      local level="$1"
      local line
      sed -u -e $'s/\033\\[[0-9;]*[a-zA-Z]//g' -e 's/\r//g' | \
      while IFS= read -r line || [ -n "$line" ]; do
        _status "$level" "$line"
      done
    }
    # <<<END output-render
  '';
in
{
  inherit core render;
  full = core + render;
}
