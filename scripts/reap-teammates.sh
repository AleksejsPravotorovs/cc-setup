#!/usr/bin/env bash
# reap-teammates.sh - the single source of truth for "is a teammate still alive?"
#
# WHY THIS EXISTS (2026-08-08, owner):
#   "you forget to turn them off repeatedly. This is not the first time."
#
# Two separate defects produced that, and neither was carelessness alone:
#   1. Teardown was a five-step protocol a human (or model) had to remember.
#   2. Its verification step LIED. `ListAgents` reported "No reachable agents"
#      while the teammate process was still running and still resident. So even
#      a careful run of the protocol produced a false "confirmed gone".
# The fix is to stop relying on either. `ps` on the PID is the only proof, and
# the hooks in .claude/settings.json call this script so the harness does the
# teardown instead of anybody remembering to.
#
# USAGE
#   scripts/reap-teammates.sh --check          list live teammates; exit 1 if any
#   scripts/reap-teammates.sh --reap           kill every live teammate
#   scripts/reap-teammates.sh --reap --session <id>   only that session's
#   scripts/reap-teammates.sh --sweep          kill only teammates whose task has
#                                              COMPLETED (Stop hook)
#   scripts/reap-teammates.sh --mark-done      record a completion (SubagentStop)
#   scripts/reap-teammates.sh --note-idle      report an idle ping, authorises nothing
#   scripts/reap-teammates.sh --clear-idle     forget markers (SubagentStart)
#   add --json to emit hook-shaped JSON on stdout instead of plain text
#
# WHAT COUNTS AS "FINISHED" - measured, not assumed (2026-08-08)
# The first build of this script reaped on TeammateIdle and killed a teammate
# mid-`sleep 90`. Reproduced deliberately: spawned an agent whose only job was
# `sleep 120`, confirmed the sleep was running, and TeammateIdle had ALREADY
# fired for it. So idle means "between turns", NOT "done" - an agent waiting on
# a long tool call reports idle while it is very much working.
# SubagentStop is the completion signal, and it is the only thing allowed to
# authorise a kill here. TeammateIdle is kept purely as a notice.
#
# SAFETY, in order of how badly each would go wrong:
#   - NEVER kills by image name. `pkill node` / `taskkill /IM` would take down
#     the harness running this script. Everything here kills a specific PID.
#   - NEVER kills the lead. A teammate is identified by --agent-id AND
#     --agent-name AND --parent-session-id in its argv; the lead has none.
#   - NEVER matches itself. `pgrep -f` finds the searcher's own argv (measured:
#     a `grep -- --agent-id` matched its own command line on this machine), so
#     this reads `ps` and excludes its own PID, its parent, and any line naming
#     this script.
set -uo pipefail

MARK_DIR="${TMPDIR:-/tmp}/claude-teammate-idle"
MODE="check"
SESSION=""
JSON=0

while [ $# -gt 0 ]; do
  case "$1" in
    --check|--list) MODE="check" ;;
    --reap)         MODE="reap" ;;
    --sweep)        MODE="sweep" ;;
    --mark-done)    MODE="mark-done" ;;
    --note-idle|--mark-idle) MODE="note-idle" ;;
    --clear-idle)   MODE="clear-idle" ;;
    --session)      SESSION="${2:-}"; shift ;;
    --json)         JSON=1 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done

# ── Find teammates ──────────────────────────────────────────────────────────
# Requires all three teammate-only flags so a shell pipeline that merely
# mentions one of them (this script's own invocation, a grep, an editor) can
# never be mistaken for an agent.
live_teammates() {  # -> "pid<TAB>name<TAB>session<TAB>etime"
  ps -Ao pid=,etime=,args= \
    | awk -v self="$$" -v parent="$PPID" -v want="$SESSION" '
        $1 == self || $1 == parent { next }
        index($0, "reap-teammates") { next }
        !index($0, "--agent-id")   { next }
        !index($0, "--agent-name") { next }
        !index($0, "--parent-session-id") { next }
        {
          pid = $1; et = $2; name = "?"; sess = "?"
          for (i = 3; i < NF; i++) {
            if ($i == "--agent-name")        name = $(i+1)
            else if ($i == "--parent-session-id") sess = $(i+1)
          }
          if (want != "" && sess != want) next
          printf "%s\t%s\t%s\t%s\n", pid, name, sess, et
        }'
}

pane_for_pid() {  # tmux pane hosting $1, empty if none
  command -v tmux >/dev/null 2>&1 || return 0
  tmux list-panes -a -F '#{pane_id} #{pane_pid}' 2>/dev/null \
    | awk -v p="$1" '$2 == p { print $1; exit }'
}

# Kill ONE pid: its tmux pane first (that reaps the process and removes the
# orphaned pane from issue #29787 in one step), then TERM, then KILL.
kill_teammate() {
  local pid="$1" pane
  pane="$(pane_for_pid "$pid")"
  [ -n "$pane" ] && tmux kill-pane -t "$pane" 2>/dev/null
  kill -TERM "$pid" 2>/dev/null
  local i=0
  while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do
    command sleep 0.5; i=$((i + 1))
  done
  kill -0 "$pid" 2>/dev/null && kill -KILL "$pid" 2>/dev/null
  command sleep 0.3
  ! kill -0 "$pid" 2>/dev/null   # exit status IS the verification
}

emit() {  # $1 human line, $2 exit code
  if [ "$JSON" = 1 ]; then
    printf '%s' "$1" | python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.stdin.read().strip()}))'
  else
    printf '%s\n' "$1"
  fi
  exit "${2:-0}"
}

case "$MODE" in

check)
  found="$(live_teammates)"
  if [ -z "$found" ]; then
    emit "No live teammates." 0
  fi
  n=$(printf '%s\n' "$found" | grep -c .)
  emit "$n live teammate(s): $(printf '%s\n' "$found" | awk '{printf "%s(pid %s, up %s) ", $2, $1, $4}')" 1
  ;;

reap)
  found="$(live_teammates)"
  [ -z "$found" ] && emit "No live teammates to reap." 0
  killed=""; failed=""
  while IFS=$'\t' read -r pid name sess et; do
    [ -z "${pid:-}" ] && continue
    if kill_teammate "$pid"; then killed="$killed $name(pid $pid)"; else failed="$failed $name(pid $pid)"; fi
  done <<< "$found"
  rm -f "$MARK_DIR"/* 2>/dev/null
  [ -n "$failed" ] && emit "Reaped:$killed. STILL ALIVE:$failed - investigate." 1
  emit "Reaped teammate(s):$killed" 0
  ;;

# Stop hook - runs at the end of every assistant turn. Reaps ONLY teammates
# whose task actually completed (a .done marker written by SubagentStop). A
# teammate with no marker is working and is never touched, only reported. There
# is deliberately no "probably done" heuristic here: the first version had one
# and it killed a working agent.
sweep)
  found="$(live_teammates)"
  [ -z "$found" ] && { rm -f "$MARK_DIR"/* 2>/dev/null; emit "No live teammates." 0; }

  done_names="$(cat "$MARK_DIR"/*.done 2>/dev/null | sort -u)"
  killed=""; kept=""
  while IFS=$'\t' read -r pid name sess et; do
    [ -z "${pid:-}" ] && continue
    if [ -n "$done_names" ] && printf '%s\n' "$done_names" | grep -qx -- "$name"; then
      if kill_teammate "$pid"; then killed="$killed $name(pid $pid)"
      else killed="$killed $name(pid $pid, KILL FAILED)"; fi
      grep -lx -- "$name" "$MARK_DIR"/*.done 2>/dev/null | while read -r m; do rm -f "$m"; done
    else
      kept="$kept $name(pid $pid, up $et)"
    fi
  done <<< "$found"

  NAG="Kill it when its deliverable is verified: scripts/reap-teammates.sh --reap"
  [ -n "$killed" ] && [ -n "$kept" ] && emit "Reaped finished teammate(s):$killed. STILL RESIDENT:$kept. $NAG" 0
  [ -n "$killed" ] && emit "Reaped finished teammate(s):$killed" 0
  emit "TEAMMATE STILL RESIDENT:$kept. $NAG" 0
  ;;

# SubagentStop hook - the ONLY signal allowed to authorise a kill. Records the
# name so --sweep can be precise; the raw payload is kept beside it because the
# field names for this event are not documented anywhere I could check, and a
# real firing is what proves them.
mark-done)
  mkdir -p "$MARK_DIR"
  payload="$(cat)"
  stamp="$(date +%s)-$$"
  name="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
def dig(o):
    if isinstance(o, dict):
        for k in ("teammate_name", "agent_name", "subagent_name", "name", "agent"):
            v = o.get(k)
            if isinstance(v, str) and v:
                return v
        for v in o.values():
            r = dig(v)
            if r:
                return r
    return ""
print(dig(d))
' 2>/dev/null)"
  printf '%s' "$payload" > "$MARK_DIR/$stamp.payload"
  if [ -n "$name" ]; then
    printf '%s\n' "${name%%@*}" > "$MARK_DIR/$stamp.done"
    emit "Teammate ${name%%@*} finished - it will be reaped at the end of this turn." 0
  fi
  emit "A subagent finished but the payload carried no name; it will NOT be auto-reaped. Check scripts/reap-teammates.sh --check." 0
  ;;

# TeammateIdle hook. Notice ONLY. Measured 2026-08-08: this fires while an agent
# is mid tool call, so it authorises nothing and writes no marker.
note-idle)
  name="$(cat | python3 -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
print(d.get("teammate_name") or "")' 2>/dev/null)"
  emit "Teammate ${name:-?} reported idle (not proof it finished)." 0
  ;;

clear-idle)
  rm -f "$MARK_DIR"/* 2>/dev/null
  emit "Idle markers cleared." 0
  ;;

# A MODE with no arm used to fall straight off the end of the case and exit 0
# with no output - a hook wired to a renamed flag would have silently done
# nothing forever. Fail loudly instead.
*)
  echo "reap-teammates.sh: unhandled mode '$MODE' - the flag parser and the case block disagree" >&2
  exit 2
  ;;

esac
