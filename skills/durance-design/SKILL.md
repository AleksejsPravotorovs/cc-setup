---
name: durance-design
description: The fleet's design and frontend doctrine, distilled from the durance.dev rework (finseo.ai-modelled, shipped 2026-09-23). Produces websites that read as an established, trustworthy, professional company, with motion on almost every block. Load FIRST whenever the user says "design", "frontend", "landing", "website", "homepage", "redesign", "UI", "hero", "section", "make it look good", or names a reference site to copy. Rules, tokens, motion recipes, the process and the gates.
---
<!-- fleet: durance-design v1 (2026-09-28). Managed by cc-setup/scripts/propagate-durance-design.sh and pp-update. Project-specific rules go in the project CLAUDE.md, not here. -->

# durance-design

**What this produces:** a site that a stranger reads as "this company has been on the market
for a long time and knows what it is doing." The feel comes from four things, in this order:
a trust narrative (proof before pitch), a disciplined token system (three grounds, one accent,
nothing under 4.5:1), quiet confident typography (weight 450, sentence case, full stops), and
motion on almost every block that never asks for attention (600ms glide-ins, ambient loops
that pause offscreen, hover only on things you can click).

**The reference result:** https://durance.dev (source: `~/Downloads/durance.dev/app/(site)/`).
**The model it copied:** https://www.finseo.ai. Any new build is measured against one such
live reference, never against the previous version of the same site.

**Read the reference files as you need them** (same folder, `references/`):
- `visual-system.md` - page skeleton, bands, tokens with exact values, type scale, every
  component's measurements, trust signals, grouping and contrast rules, copy rules, assets.
- `motion.md` - the reveal primitive, the section-by-section inventory of what moves,
  seamless loops, hover rules, performance rules, the motion vocabulary table.
- `process-and-gates.md` - the ten-step pipeline, the exact verification commands, 25
  lessons as symptom -> root cause -> rule, standing owner rulings, team shape, asset production.

**Drop-in code** (`templates/`): `MotionController.tsx`, `MotionToggle.tsx`, `reveal.css`
(reveal primitive + keyframe library + pause rules), `tokens.css` (the palette as semantic
band variables with `@property` registration). **Tools** (`scripts/`): `shoot-page.mjs`
(filmstrips over real Chrome), `check-design.sh` (long-dash and literal-hex lock),
`hf-cap.sh` (image-generation cost cap).

## 0. Before touching anything

1. Restate the goal in one line: what should a stranger conclude after ten seconds on the page?
2. Read the real files you will touch: the stylesheet `:root`, the Tailwind theme, the layout,
   one existing section. Confirm the stack from the project `CLAUDE.md`. Never act on an
   assumed structure. Under 250 lines, read the whole file.
3. If the user named a reference site, capture it first (section 5). If they did not and the
   work is a new page or a redesign, propose one concrete URL in one line and proceed on it.
4. Never inline a literal hex, never add a dependency for motion, never ask "should I".

## 1. The trust narrative (page order)

Claim -> legitimacy -> capability -> proof -> stakes -> terms -> method -> person -> offers -> ask:

announcement strip + nav / hero / trust bento (named clients, stack by layer, real founder) /
feature bento / case studies / stakes (globe) / stats / process grid / founder note / offers /
final CTA / footer. Proof sits BEFORE the service list.

Trust signals are terms the visitor can check, repeated across bands, never claims: one
fixed price in the strip above the nav, all prices on the offer tiles ("From €6,000",
"€1,500, fixed", "€3,000 a month"), "Taking new projects this quarter" above the H1, client
names as text marks, the full stack by layer, a real founder photo at 44px beside a quote,
a week-by-week timeline, a stats row with a source line, the legal entity and country under
the final CTA and in the footer. Rejected forever: "500+" counts, "100% production-ready",
star ratings without a third party, generated people, invented logos, a status chip with no
status page, nav chevrons with nothing to drop down.

## 2. Bands, tokens, contrast

- Three grounds only: cream `#faf9f5`, white (morph start), anthracite `#1c1c1c`. Sequence
  light, light, light->dark, dark, dark, dark, dark, light, light, dark, dark. ONE soft
  transition per page (an 800ms colour morph triggered by the case-study section); every
  other band change is a hard edge. Do not raise band deltas or strengthen full-width rules.
- Sections declare `data-band="cream|dark|morph"`; components read the semantic variables
  (`--surface`, `--surface-card`, `--fg`, `--fg-3`, `--border`) and never pick light or dark
  values themselves. Inside a band, steps are small (one fill step plus a 1px line per card).
- Tokens live in TWO files, the stylesheet `:root` and the Tailwind theme; change both. A
  missing colour is a request for a token, never a local hex. `check-design.sh` is the lock.
- Every ink tier is >= 4.5:1 on every surface of its side. Sub-4.5 tokens are DECORATION
  ONLY. Never mute content to de-emphasise it. The bright accent (`#34e3a3`) is decoration
  only on light; on light, accent that carries meaning uses accent-ink (`#1a7654`).
- **Solid accent fill means exactly one thing: the primary action.** On durance it is reserved
  and used by nothing. Primary buttons are the band's ink; secondary are bordered. Accent as
  foreground (glyphs, rules, dots, globe, beam) is the brand tint and unrestricted.
- Container 1360px, gutters 24px, sections 80/112px, reduced to 32/48px between two sections
  on the same band. A 1px dashed rail on each edge of the container runs through every band.
- Shadows are neutral, low alpha, long offset. Radii: card 6, tile 8, button 0, pill full.

## 3. Type and copy

- One sans for everything (General Sans; weight 450 for H2s, 500 for H1 and values, nothing
  above 600). One mono for 10px uppercase tags only, never eyebrows. The wordmark is locked
  to its rendered CSS from production and never inherits the display face.
- Max 3 distinct font sizes per composition (a card, a section head, a viewport). The largest
  element is the message. Every prose block has a measure cap (intro 672px, body 448-576px).
- Two-tone headings: line 1 the claim in ink, line 2 the qualifier in grey-green (`#536a5d`
  light, `#809789` dark), same size. Sentence case, full stop, 3 to 5 words a line. Line 2 is
  a contrast ("Not to drag on.") or a scope ("Front to back.").
- Team voice ("we", "one team"); the founder speaks in first person only in their own note.
  CTA names never change: "Start a project" (primary), "Book a call" (secondary). Steps are
  written as the client's outcome. Numbers are terms (weeks, prices, years), never results.
- Every string comes from a copy deck slot; builders paste, never invent. Unconfirmed facts
  carry `[ASSUMED]` or `[OWNER]`. No long dashes anywhere, hyphens only (also in chat).

## 4. Motion on almost every block

Three layers, no library (details and every value in `references/motion.md`):

1. **Reveal.** `data-reveal` on every content block (not on section heads: restraint is part
   of the look). One IntersectionObserver (`-5%` bottom margin, once, plus a `top < 0` clause
   for jumped-past content) sets `data-revealed`; CSS transitions opacity + transform, 600ms,
   `cubic-bezier(.16,1,.3,1)`, 24px up. Variants `left | right | pop | fade`; stagger by a
   per-element `data-reveal-delay="n"` (n x 60ms), never a parent variable. Hidden ONLY under
   `[data-js]`, set by an inline parse-time script, so the page reads with JS off. Reduced
   motion turns it into a 200ms fade. Never put `data-reveal` on an element that owns its own
   transform (hover lift, carousel, tilt): reveal a wrapper.
2. **Ambient loops.** Every infinite animation carries `motion-loop`; one governor pauses it
   300px offscreen, reduced motion pauses it, an on-page "Pause motion" footer toggle pauses
   it (WCAG 2.2.2), and JS loops (video, canvas, scripted chat) watch the same attribute.
   Loops are closed (first value = last), desynced with co-prime periods, spread with delays
   by index or distance, and reset while faded out. Video loops are made seamless in the
   FILE (ffmpeg `xfade` of the last 25 frames into the first 25) with the poster extracted as
   frame 0 and a new file name on every regeneration.
3. **Hover.** Movement only inside `@media (hover: hover) and (pointer: fine)`, every hover
   with a `:focus-visible` twin, and only on things that are actually links or buttons. The
   vocabulary is small: arrow nudge 2px, card lift `scale(1.012)` 300ms, photo zoom 1.03 over
   700ms, press `scale(.97)` 160ms, underline `scaleX` 250ms, beam ring opacity 300ms.

Rules that are not negotiable: `transform` and `opacity` only (colour for state), no
`transition: all`, UI under 300ms, reveals 500-1000ms, nothing appears from `scale(0)`,
`will-change` once at most, hide with `visibility` delayed past the fade (Safari paints
`opacity: 0` blur as a grey ghost) and `inert` when hidden, `content-visibility: auto` with
MEASURED intrinsic sizes, native scroll and no pins, observers over scroll listeners, z-index
contract (content 10-19, rails 20, header and pill 50). CSS Modules hash keyframe names, so
loops in a module declare local keyframes or use the global `.anim-*` classes.

What a block gets: the hero copy a CSS mount rise (transform only, so the H1 counts for LCP);
cards a column-staggered reveal; bento stages a bob, a dash flow, a caret, a typing loop;
stats a CSS digit roll; the process grid six co-prime "video" loops that start on reveal;
the globe a 65s rotation plus pointer repulsion; the founder dot a ping; the case slides a
1200ms zoom; the final checklist a live pulse. Look at the inventory before inventing.

## 5. The process (new page or redesign)

1. ONE live reference URL. Capture it into the repo: `node scripts/shoot-page.mjs <url>
   research/<ref>/shots-ref ref 1440 900` and `... refm 390 844 1`, plus its HTML and CSS.
2. Measure it into five specs (layout, tokens, motion, copy, assets) with provenance tags;
   five parallel researchers when the work is multi-agent. State the brand mapping once.
3. Take the design rulings, log them, surface them to the owner with an overrule phrase.
4. Write a section CONTRACT (ownership, page order and bands, copy source, shared classes and
   data attributes, behaviour rules restated locally, builder-safe verify commands, return
   format) before any section is built.
5. Build in an isolated route group; scaffold once, sections in parallel on disjoint CSS
   Modules, one integrator. Builders never run build or dev.
6. Filmstrip ours against the reference with identical arguments and READ the frames.
7. Review one triage agent per lens (fidelity, animation, doctrine, a11y + reduced motion,
   mobile), fix, verify. Ship behind the new route, then cut over with the old page parked
   at `/old` (noindex) and a permanent redirect.

## 6. Done means (run it, do not assume it)

```bash
npm run lint && npx tsc --noEmit && npm run build
bash .claude/skills/durance-design/scripts/check-design.sh
node .claude/skills/durance-design/scripts/shoot-page.mjs http://localhost:3000 research/shots ours 1440 900
```
Then the five-check visible-content table with evidence: gates green; content actually on
the page (nothing stuck at `opacity: 0`, readable with JS off, canvases screenshotted);
z-index contract; 375 / 768 / 1440 with no horizontal overflow and reduced motion cited by
line; focus rings, form states, WCAG AA, alt text. Safari-class paint issues (hide/show,
video seams) are checked in WebKit. Every outbound link is curled. Claim done only beside
fresh command output; otherwise `EDITED-UNVERIFIED: <file>`.

## 7. Pre-ship checklist

- [ ] Page order follows the trust narrative; proof before pitch; every signal is a checkable term.
- [ ] Three grounds, one morph, semantic band variables, tokens in both files, no literal hex.
- [ ] Nothing under 4.5:1 carries content; no solid accent fill outside the primary action.
- [ ] 3 sizes per composition; two-tone H2s in sentence case with full stops; measure caps.
- [ ] Team voice; CTA names unchanged; copy from slots; no long dashes.
- [ ] Every content block reveals; every loop has `motion-loop`; Pause toggle wired; reduced motion designed per element.
- [ ] Hover only on actionable, focus-visible twins, transform/opacity only, hidden = visibility + inert.
- [ ] Wordmark at exact rendered fidelity; real client marks only; imagery from Higgsfield behind the cost cap.
- [ ] Gates, filmstrips, WebKit, JS-off, links curled; receipts in the commit body.

## Standing rulings (owner)

"Keep the logo" means visual fidelity, not the string. No em- or en-dashes anywhere. Visual
assets come from the generator, never a procedural stand-in; cost on the exact argv and
report actual spend. A default beside an open owner decision is not permission when it
decides how the work looks: state it and keep building. One reference, measured, not the
previous site. Precedents lend mechanics and timings, not their look. Team voice; clients
and stack never share a row.
