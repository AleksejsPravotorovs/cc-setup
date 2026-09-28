#!/usr/bin/env bash
#
# hf-cap.sh - a cost gate in front of `higgsfield generate create` / `generate workflow`.
#
# Why this exists: no single Higgsfield generation may cost more than the cap. A rule
# written in a prompt is a sign; this script is a lock. It asks Higgsfield what the job
# WILL cost before creating it, and refuses anything above the cap. Nothing bills until
# the estimate has passed the gate. The same argv is used for `cost` and `create`, so
# the estimate is for the exact job (a costed subset is a different job).
#
# Usage:
#   scripts/hf-cap.sh <job_type> [--param value]...
#   HF_MAX_CREDITS=8 scripts/hf-cap.sh kling3_0_turbo --prompt "..." --duration 5
#   HF_DRY_RUN=1 scripts/hf-cap.sh nano_banana_pro --prompt "..."     # price only
#   HF_SUBCMD=workflow scripts/hf-cap.sh reframe --video in.mp4 --aspect_ratio 9:16
#
# Every accepted job is appended to research/higgsfield-spend.log with its estimate.
# Shipped with the durance-design skill; ledger lands at <repo>/research/higgsfield-spend.log.
set -euo pipefail

CAP="${HF_MAX_CREDITS:-20}"
SUB="${HF_SUBCMD:-create}"          # create | workflow
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LEDGER="${HF_LEDGER:-$ROOT/research/higgsfield-spend.log}"

if [ "$#" -lt 1 ]; then
  echo "usage: $(basename "$0") <job_type> [--param value]..." >&2
  exit 64
fi
case "$SUB" in create|workflow) ;; *) echo "REFUSED: HF_SUBCMD must be create or workflow, got '$SUB'" >&2; exit 64;; esac
if ! command -v higgsfield >/dev/null 2>&1; then
  echo "REFUSED: higgsfield CLI not on PATH (expected /opt/homebrew/bin/higgsfield)" >&2
  exit 127
fi

JOB_TYPE="$1"

# 1. Estimate. A non-numeric answer means the params are wrong - stop there
#    rather than letting `create` discover it after the fact.
#    The estimate must NOT carry create-only flags: `cost --video f.mp4 --wait --json` hangs
#    indefinitely (measured 2026-09-07), while the same argv without them answers in ~2 s.
COST_ARGS=(); skip=0
for a in "$@"; do
  if [ "$skip" = 1 ]; then skip=0; continue; fi
  case "$a" in
    --wait|--json) continue;;
    --wait-timeout|--wait-interval) skip=1; continue;;
    --wait-timeout=*|--wait-interval=*) continue;;
  esac
  COST_ARGS+=("$a")
done
COST_JSON="$(higgsfield generate cost "${COST_ARGS[@]}" --json 2>&1)" || {
  echo "REFUSED: cost estimate failed for '$JOB_TYPE'" >&2
  echo "$COST_JSON" >&2
  exit 65
}
COST="$(printf '%s' "$COST_JSON" | tr -d ' \n' | grep -o '"credits":[0-9.]*' | cut -d: -f2 || true)"
if [ -z "$COST" ]; then
  echo "REFUSED: could not read a credit estimate for '$JOB_TYPE'" >&2
  echo "$COST_JSON" >&2
  exit 65
fi

# 2. Gate. awk does the float compare that test(1) cannot.
if awk -v c="$COST" -v cap="$CAP" 'BEGIN { exit !(c > cap) }'; then
  echo "REFUSED: $JOB_TYPE would cost ${COST} credits, cap is ${CAP}." >&2
  echo "Nothing was created and nothing was billed." >&2
  echo "Lower --duration or --resolution, drop audio, or raise HF_MAX_CREDITS deliberately." >&2
  exit 3
fi
echo "OK: ${JOB_TYPE} estimated at ${COST} credits (cap ${CAP})." >&2

if [ -n "${HF_DRY_RUN:-}" ]; then
  echo "HF_DRY_RUN set - stopping before create." >&2
  exit 0
fi

# 3. Create, and only then write the ledger line. stdout carries ONLY the CLI's output
#    so callers can parse it (hf-gen.sh reads the JSON).
mkdir -p "$(dirname "$LEDGER")"
OUT="$(higgsfield generate "$SUB" "$@")"
# ledger summary: the result URL when the JSON has one, else a short prefix of the output
SUMMARY="$(printf '%s' "$OUT" | jq -r '.. | objects | .result_url? // empty' 2>/dev/null | head -1 || true)"
[ -n "$SUMMARY" ] || SUMMARY="$(printf '%s' "$OUT" | tr '\n' ' ' | cut -c1-200)"
printf '%s\t%s\t%s credits\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$JOB_TYPE" "$COST" "$SUMMARY" >> "$LEDGER"
printf '%s\n' "$OUT"
echo "(logged to ${LEDGER#"$ROOT"/})" >&2
