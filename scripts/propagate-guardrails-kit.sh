#!/usr/bin/env bash
# propagate-guardrails-kit.sh
# Idempotently install the Guardrails Kit into every active project tracked in
# the Obsidian vault's Projects/<slug>.md notes:
#   1. sync the on-demand playbooks into  <local_path>/docs/guardrails/*.md
#   2. upsert the always-loaded GUARDRAILS_KIT block into  <local_path>/CLAUDE.md
#
# The kit source is this cc-setup clone's docs/guardrails/ (already vendored with
# U+2014 converted to U+2013 per house style). Re-running replaces (never
# duplicates) the block and re-syncs any drifted playbook. Content outside the
# markers is preserved. Same reads-local_path-from-frontmatter contract and
# skip rules as propagate-frontend-policy.sh.
#
# Usage:
#   ./scripts/propagate-guardrails-kit.sh --dry-run --verbose
#   ./scripts/propagate-guardrails-kit.sh --only novashop
#   ./scripts/propagate-guardrails-kit.sh                   # writes for real
#
# Skip rules:  Projects/_archived/, names starting with _, README, *-state,
#              status: archived, missing/empty local_path, missing local dir.
#
# Safety guards (identical philosophy to propagate-frontend-policy.sh):
#   - Symlinked CLAUDE.md is REFUSED (would break shared-link semantics).
#   - REPLACE requires both BEGIN and END markers; a truncated end-marker errors
#     and leaves the file untouched.
#   - REPLACE verifies the rewritten file is non-empty AND >=50% of original size.
#   - Overwriting a customized in-marker block prints a WARN with the file path.
#
# Compatible with bash 3.2 (macOS system bash).

set -euo pipefail

VAULT="/Users/aleksejpravotorov/Desktop/My AI Knowledge Base"
PROJECTS_DIR="$VAULT/Projects"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_SRC="$(cd "$SCRIPT_DIR/.." && pwd)/docs/guardrails"
BLOCK_FILE="$KIT_SRC/_CLAUDE_BLOCK.md"

# The playbooks that ship into every project (the installable kit).
PLAYBOOKS="PLAN CODE TRAPS DEBUG VERIFY EFFICIENCY SESSION _FORMAT"

# Markers are derived from the block file's first/last lines (below), so they
# byte-match the vendored block exactly regardless of dash conversion.
BEGIN_MARKER=""
END_MARKER=""

DRY_RUN=0
VERBOSE=0
ONLY=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --verbose|-v) VERBOSE=1 ;;
    --only)
      shift
      ONLY="${1:-}"
      if [ -z "$ONLY" ]; then
        echo "ERROR: --only requires a slug argument" >&2
        exit 2
      fi
      ;;
    -h|--help)
      /usr/bin/sed -n '2,/^$/p' "$0" | /usr/bin/sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { if [ "$VERBOSE" = "1" ]; then echo "$*" >&2; fi; }

# Counters
COUNT_UPDATED=0
COUNT_CREATED=0
COUNT_REPLACED=0
COUNT_APPENDED=0
COUNT_NOOP=0
COUNT_SKIP=0
DOCS_SYNCED=0
ERRORS=0
MATCHED_ONLY=0

# Preflight: the kit source must exist before we touch any project.
if [ ! -f "$BLOCK_FILE" ]; then
  echo "ERROR: block source not found: $BLOCK_FILE (run from a cc-setup clone with docs/guardrails/ vendored)" >&2
  exit 2
fi
for p in $PLAYBOOKS; do
  if [ ! -f "$KIT_SRC/$p.md" ]; then
    echo "ERROR: playbook source missing: $KIT_SRC/$p.md" >&2
    exit 2
  fi
done

if [ -n "$ONLY" ] && [ ! -f "$PROJECTS_DIR/$ONLY.md" ]; then
  echo "ERROR: --only slug '$ONLY' did not match any project note in $PROJECTS_DIR" >&2
  exit 1
fi

BLOCK_CONTENT="$(cat "$BLOCK_FILE")"
BEGIN_MARKER="$(/usr/bin/head -n 1 "$BLOCK_FILE")"
END_MARKER="$(/usr/bin/tail -n 1 "$BLOCK_FILE")"
if [ -z "$BEGIN_MARKER" ] || [ -z "$END_MARKER" ]; then
  echo "ERROR: could not derive markers from $BLOCK_FILE" >&2
  exit 2
fi

# Extract a frontmatter scalar (first --- block at top of file).
get_frontmatter_value() {
  local file="$1" key="$2"
  /usr/bin/awk -v k="$key" '
    BEGIN { in_fm = 0 }
    NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; next }
    in_fm && /^---[[:space:]]*$/ { exit }
    in_fm {
      if (match($0, "^[[:space:]]*" k "[[:space:]]*:[[:space:]]*")) {
        v = substr($0, RLENGTH + 1)
        sub(/[[:space:]]+$/, "", v)
        if (v ~ /^".*"$/) { v = substr(v, 2, length(v) - 2) }
        else if (v ~ /^\x27.*\x27$/) { v = substr(v, 2, length(v) - 2) }
        print v
        exit
      }
    }
  ' "$file"
}

# Sync the 8 playbooks into <dir>/docs/guardrails/. Copies only changed files.
# Sets DOCS_SYNCED_THIS to the number copied for the current project.
DOCS_SYNCED_THIS=0
sync_playbooks() {
  local dir="$1"
  local dest="$dir/docs/guardrails"
  DOCS_SYNCED_THIS=0
  local p src dst
  for p in $PLAYBOOKS; do
    src="$KIT_SRC/$p.md"
    dst="$dest/$p.md"
    if [ -L "$dst" ]; then
      echo "ERROR: $dst is a symlink — refusing to overwrite" >&2
      ERRORS=$((ERRORS + 1))
      continue
    fi
    if [ -f "$dst" ] && /usr/bin/cmp -s "$src" "$dst"; then
      continue
    fi
    if [ "$DRY_RUN" = "1" ]; then
      log "DRY: would sync $dst"
      DOCS_SYNCED_THIS=$((DOCS_SYNCED_THIS + 1))
      continue
    fi
    /bin/mkdir -p "$dest"
    /bin/cp "$src" "$dst"
    log "SYNC: $dst"
    DOCS_SYNCED_THIS=$((DOCS_SYNCED_THIS + 1))
  done
}

# Replace marked block in $1 with $2, OR append if no markers. Leaves target
# UNTOUCHED on any internal failure and returns non-zero. Callers MUST capture rc.
UPSERT_RESULT=""
upsert_block() {
  local target="$1"
  local block_content="$2"
  UPSERT_RESULT=""
  local tmp blockfile awk_rc orig_size new_size half_orig

  if [ -L "$target" ]; then
    echo "ERROR: $target is a symlink — refusing to rewrite (would break shared-link semantics). Resolve manually." >&2
    return 5
  fi

  if /usr/bin/grep -qF "$BEGIN_MARKER" "$target" 2>/dev/null; then
    if ! /usr/bin/grep -qF "$END_MARKER" "$target" 2>/dev/null; then
      echo "ERROR: $target has BEGIN marker but missing END marker — refusing to rewrite (manual review required)" >&2
      return 6
    fi

    blockfile=$(/usr/bin/mktemp -t guardrails-block.XXXXXX)
    printf '%s\n' "$block_content" > "$blockfile"
    tmp=$(/usr/bin/mktemp -t guardrails-target.XXXXXX)

    set +e
    /usr/bin/awk \
      -v BLOCK_FILE="$blockfile" \
      -v begin="$BEGIN_MARKER" \
      -v end="$END_MARKER" \
      '
        BEGIN {
          block = ""
          while ((getline line < BLOCK_FILE) > 0) {
            block = block (block == "" ? "" : "\n") line
          }
          close(BLOCK_FILE)
          skipping = 0; printed = 0
        }
        index($0, begin) > 0 {
          if (!printed) { print block; printed = 1 }
          skipping = 1
          next
        }
        skipping && index($0, end) > 0 {
          skipping = 0
          next
        }
        skipping { next }
        { print }
      ' "$target" > "$tmp"
    awk_rc=$?
    set -e

    /bin/rm -f "$blockfile"

    if [ "$awk_rc" -ne 0 ]; then
      echo "ERROR: awk REPLACE failed (rc=$awk_rc) on $target — leaving file untouched" >&2
      /bin/rm -f "$tmp"
      return 2
    fi

    orig_size=$(/usr/bin/wc -c < "$target" | /usr/bin/tr -d ' ')
    new_size=$(/usr/bin/wc -c < "$tmp" | /usr/bin/tr -d ' ')
    if [ "$new_size" -le 0 ]; then
      echo "ERROR: refusing empty replacement of $target (orig=$orig_size, new=$new_size)" >&2
      /bin/rm -f "$tmp"
      return 3
    fi
    half_orig=$((orig_size / 2))
    if [ "$orig_size" -gt 0 ] && [ "$new_size" -lt "$half_orig" ]; then
      echo "ERROR: replacement of $target shrank from $orig_size to $new_size bytes (>50% loss) — refusing" >&2
      /bin/rm -f "$tmp"
      return 4
    fi

    /bin/mv "$tmp" "$target"
    UPSERT_RESULT="replaced"
    return 0
  else
    tmp=$(/usr/bin/mktemp -t guardrails-target.XXXXXX)
    /bin/cp "$target" "$tmp"
    if [ -s "$tmp" ]; then
      if [ -n "$(/usr/bin/tail -c 1 "$tmp")" ]; then
        printf '\n' >> "$tmp"
      fi
      printf '\n' >> "$tmp"
    fi
    printf '%s\n' "$block_content" >> "$tmp"

    new_size=$(/usr/bin/wc -c < "$tmp" | /usr/bin/tr -d ' ')
    if [ "$new_size" -le 0 ]; then
      echo "ERROR: refusing empty append result for $target" >&2
      /bin/rm -f "$tmp"
      return 3
    fi

    /bin/mv "$tmp" "$target"
    UPSERT_RESULT="appended"
    return 0
  fi
}

process_project() {
  local note="$1"
  local base="${note##*/}"
  base="${base%.md}"

  case "$base" in
    _*|README|readme|Readme) log "skip: $base (system file)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0 ;;
    *-state) log "skip: $base (prime snapshot, not a project note)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0 ;;
  esac

  if [ -n "$ONLY" ] && [ "$base" != "$ONLY" ]; then
    return 0
  fi

  local status local_path
  status=$(get_frontmatter_value "$note" "status")
  local_path=$(get_frontmatter_value "$note" "local_path")

  if [ "$status" = "archived" ]; then
    log "skip: $base (status=archived)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi
  if [ -z "$local_path" ]; then
    log "skip: $base (no local_path in frontmatter)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi
  if [ ! -d "$local_path" ]; then
    log "skip: $base (local_path does not exist: $local_path)"; COUNT_SKIP=$((COUNT_SKIP + 1)); return 0
  fi

  if [ -n "$ONLY" ]; then MATCHED_ONLY=1; fi

  # ── 1. playbooks ────────────────────────────────────────────────
  sync_playbooks "$local_path"
  DOCS_SYNCED=$((DOCS_SYNCED + DOCS_SYNCED_THIS))

  # ── 2. CLAUDE.md block ──────────────────────────────────────────
  local target="$local_path/CLAUDE.md"

  if [ ! -f "$target" ]; then
    if [ -L "$target" ]; then
      echo "ERROR: $target is a broken symlink — refusing to create a regular file in its place" >&2
      ERRORS=$((ERRORS + 1)); return 0
    fi
    if [ "$DRY_RUN" = "1" ]; then
      log "DRY: would create $target"; COUNT_CREATED=$((COUNT_CREATED + 1)); COUNT_UPDATED=$((COUNT_UPDATED + 1)); return 0
    fi
    if ! /usr/bin/touch "$target" 2>/dev/null; then
      echo "ERROR: cannot create $target (permission denied?)" >&2; ERRORS=$((ERRORS + 1)); return 0
    fi
    {
      printf '# %s\n\n' "$base"
      printf '%s\n' "$BLOCK_CONTENT"
    } > "$target"
    log "CREATE: $target"; COUNT_CREATED=$((COUNT_CREATED + 1)); COUNT_UPDATED=$((COUNT_UPDATED + 1)); return 0
  fi

  local has_marker existing_block matches=0
  has_marker=0
  if /usr/bin/grep -qF "$BEGIN_MARKER" "$target" 2>/dev/null; then
    has_marker=1
    existing_block=$(/usr/bin/awk \
      -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
        index($0, begin) > 0 { capturing = 1 }
        capturing { print }
        capturing && index($0, end) > 0 { exit }
      ' "$target")
    if [ "$existing_block" = "$BLOCK_CONTENT" ]; then matches=1; fi
  fi

  if [ "$matches" = "1" ]; then
    log "ok:    $target (block already up-to-date)"; COUNT_NOOP=$((COUNT_NOOP + 1)); return 0
  fi

  if [ "$has_marker" = "1" ]; then
    echo "WARN: replacing customized in-marker block in $target" >&2
  fi

  if [ "$DRY_RUN" = "1" ]; then
    if [ "$has_marker" = "1" ]; then
      log "DRY: would replace block in $target"; COUNT_REPLACED=$((COUNT_REPLACED + 1))
    else
      log "DRY: would append block to $target"; COUNT_APPENDED=$((COUNT_APPENDED + 1))
    fi
    COUNT_UPDATED=$((COUNT_UPDATED + 1)); return 0
  fi

  if [ ! -w "$target" ]; then
    echo "ERROR: $target is not writable" >&2; ERRORS=$((ERRORS + 1)); return 0
  fi

  local upsert_rc=0
  upsert_block "$target" "$BLOCK_CONTENT" || upsert_rc=$?
  if [ "$upsert_rc" -ne 0 ]; then
    echo "ERROR: upsert failed for $target (rc=$upsert_rc)" >&2; ERRORS=$((ERRORS + 1)); return 0
  fi

  case "$UPSERT_RESULT" in
    replaced) log "REPLACE: $target"; COUNT_REPLACED=$((COUNT_REPLACED + 1)) ;;
    appended) log "APPEND:  $target"; COUNT_APPENDED=$((COUNT_APPENDED + 1)) ;;
    *) echo "ERROR: upsert returned unexpected result '$UPSERT_RESULT' for $target" >&2; ERRORS=$((ERRORS + 1)); return 0 ;;
  esac
  COUNT_UPDATED=$((COUNT_UPDATED + 1))
}

if [ ! -d "$PROJECTS_DIR" ]; then
  echo "ERROR: Projects dir not found: $PROJECTS_DIR" >&2
  exit 2
fi

shopt -s nullglob
for note in "$PROJECTS_DIR"/*.md; do
  [ -f "$note" ] || continue
  process_project "$note"
done
shopt -u nullglob

if [ -n "$ONLY" ] && [ "$MATCHED_ONLY" -eq 0 ]; then
  echo "ERROR: --only slug '$ONLY' matched a note but the project was filtered out (status=archived, missing local_path, or local dir not present)" >&2
  exit 1
fi

MODE="LIVE"
[ "$DRY_RUN" = "1" ] && MODE="DRY-RUN"
echo ""
echo "[$MODE] CLAUDE.md updated: $COUNT_UPDATED (created: $COUNT_CREATED, replaced: $COUNT_REPLACED, appended: $COUNT_APPENDED) | NoOp: $COUNT_NOOP | Playbooks synced: $DOCS_SYNCED | Skipped: $COUNT_SKIP | Errors: $ERRORS"

if [ "$ERRORS" -gt 0 ]; then exit 1; fi
exit 0
