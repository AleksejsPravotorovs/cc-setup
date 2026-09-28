#!/usr/bin/env bash
# check-design.sh - the durance-design house-style lock. Signs are prompts; this is code.
#
#   1. No long dashes (U+2014 em, U+2013 en) anywhere in the repo. Owner instruction,
#      2026-08-15: "I do not want to see em-dashes. Not here or in the website."
#   2. No literal hex colour in components (tsx/jsx/vue/svelte/astro under app/, src/,
#      components/, pages/). Tokens live in the stylesheet :root and the Tailwind theme.
#
# perl, not `grep -P`: BSD grep has no -P and exits 2, and under zsh a GNU grep on PATH
# can make the same command "work" interactively while doing nothing from a script.
# Files come from `git ls-files`, so .gitignore is honoured.
#
# Usage: bash .claude/skills/durance-design/scripts/check-design.sh
#        DESIGN_CHECK_EXCLUDE='^app/fonts/|^public/' ...   (extra path regex to skip)
# Exit:  0 clean, 1 violated.
set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
RED=$'\033[31m'; GREEN=$'\033[32m'; OFF=$'\033[0m'; fail=0
EXTRA_EXC="${DESIGN_CHECK_EXCLUDE:-}"

scan() {
  local pat="$1" inc="${2:-}" exc="${3:-}"
  git ls-files -co --exclude-standard -z 2>/dev/null \
    | PAT="$pat" INC="$inc" EXC="$exc" perl -0 -CSD -ne '
        BEGIN { die "empty pattern\n" unless length $ENV{PAT};
          $pat = qr/$ENV{PAT}/; $inc = length $ENV{INC} ? qr/$ENV{INC}/ : qr/(?:)/;
          $exc = length $ENV{EXC} ? qr/$ENV{EXC}/ : qr/(?!)/; }
        my $f = $_; chomp $f;
        next unless -f $f && ! -B $f; next unless $f =~ $inc; next if $f =~ $exc;
        local $/ = "\n"; open my $fh, "<:encoding(UTF-8)", $f or next;
        while (my $l = <$fh>) { next unless $l =~ $pat; chomp $l; print "$f:$.:$l\n"; }
        close $fh;'
}
report() {
  if [ -n "$2" ]; then printf '%sFAIL%s %s\n' "$RED" "$OFF" "$1"; printf '%s\n' "$2" | sed 's/^/     /' | head -40; fail=1
  else printf '%sPASS%s %s\n' "$GREEN" "$OFF" "$1"; fi
}

exc1='(^|/)(node_modules|\.next|dist|build|out|coverage)/|\.(lock|min\.js|min\.css|svg|map)$|^\.claude/|^research/|^docs/|^findings\.md$|^decomposition\.md$|(^|/)fonts?/'
[ -n "$EXTRA_EXC" ] && exc1="$exc1|$EXTRA_EXC"
hits="$(scan '[\x{2014}\x{2013}]' '' "$exc1")"
report "no long dashes (U+2014, U+2013) in shipped files" "$hits"

exc2='(^|/)(node_modules|\.next|dist|build|out)/|/dev/|\.stories\.'
[ -n "$EXTRA_EXC" ] && exc2="$exc2|$EXTRA_EXC"
hits="$(scan '(?<![&\w])#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|[0-9a-fA-F]{3})\b' \
  '^(app|src|components|pages)/.*\.(tsx|jsx|vue|svelte|astro)$' "$exc2")"
report "no literal hex in components (tokens live in the stylesheet and the Tailwind theme)" "$hits"

echo
if [ "$fail" -eq 0 ]; then printf '%sdurance-design locks pass.%s\n' "$GREEN" "$OFF"
else printf '%sLock failed. Fix the root cause; never weaken this check.%s\n' "$RED" "$OFF"; fi
exit "$fail"
