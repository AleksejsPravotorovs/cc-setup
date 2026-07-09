# Guardrails Kit - provenance & integration notes

**Source:** https://github.com/TheColliny/FableClaudeMDForOpus (v1.0)
**Vendored into cc-setup:** 2026-07-09

## What this is
A portable set of coding guardrails that convert the implicit judgment a frontier
model (Fable 5) applies automatically into explicit, event-triggered procedures a
weaker model (Opus / Sonnet) can execute mechanically - fewer logic errors, fewer
introduced bugs, fewer wasted tokens.

- `PLAN CODE TRAPS DEBUG VERIFY EFFICIENCY SESSION _FORMAT` (`.md`) - the 8 on-demand
  playbooks. Read at the moment their trigger fires (routing table in the block).
- `_CLAUDE_BLOCK.md` - the always-loaded core (routing table + iron rules + hard
  stops) that ships into every project's `CLAUDE.md` between `GUARDRAILS_KIT` markers.

## How it differs from upstream
1. **U+2014 -> U+2013.** Every em-dash was converted to an en-dash per the house
   no-em-dash rule. This means these files intentionally do NOT hash-match upstream;
   do not "restore" em-dashes.
2. **Block-injection instead of MIGRATE.md.** Upstream ships an interactive,
   per-project `MIGRATE.md` rewrite that stops for approval. We do not use it - it
   would tear apart the fleet's hand-built `CLAUDE.md` files. Instead the kit is a
   sentinel-bracketed managed block appended alongside the existing PROMPT-FREE
   protocol, exactly like `FRONTEND_SKILL_POLICY`.
3. **Precedence header.** The block opens with a note reconciling the one genuine
   conflict: a kit Hard-stop "wait for approval" on an irreversible action overrides
   `AGENTS.md` Rule 3 "never ask" (Rule 3 bans clarifying questions, not safety stops).

## Distribution
- `scripts/propagate-guardrails-kit.sh` - installs the block + playbooks into every
  active project tracked in the Obsidian vault (`Projects/<slug>.md` -> `local_path`).
  Idempotent; re-run any time. `--dry-run`, `--verbose`, `--only <slug>` supported.
- `scripts/update.sh` (pp-update) - bootstrapped-project mode downloads the 8
  playbooks so future projects get them without a vault present.

## Upgrading
Re-clone upstream, re-run the em-dash conversion into `docs/guardrails/`, rebuild
`_CLAUDE_BLOCK.md` from the new `CLAUDE.md` CORE + FOOTER, then re-run the propagation
script. Never hand-edit vendored playbook wording (see `_FORMAT.md` F15).
