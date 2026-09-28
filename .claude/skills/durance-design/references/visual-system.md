# Visual system: the "on the market for good" look

Distilled from durance.dev (`app/(site)/`, the finseo.ai-modelled build, cutover
2026-09-23). Every rule is checkable by looking at a render or a stylesheet. The
values are the durance recipe; swap the brand hue, keep the ratios. Provenance
lives in `durance.dev/research/skill-mining/visual-system.md` with `file:line`.

## 1. Page skeleton: the trust narrative

The order is fixed because it is an argument, not a list:

| # | Section | Ground | What the visitor concludes |
|---|---|---|---|
| 0 | Announcement strip + nav | black strip, glass nav | "They sell a real, priced product" (one fixed-price offer in the strip) |
| 1 | Hero | light | The claim, availability, who it is for, a live-looking product mock |
| 2 | Trust bento | light | Legitimacy: named clients, the full stack by layer, a real founder |
| 3 | Feature bento | light -> dark morph | Capability: 6 to 8 service cards, each with a product mock |
| 4 | Case studies | morph trigger | Proof: shipped work on full-bleed photography |
| 5 | Globe / stakes | dark | Why the work matters beyond the website |
| 6 | Stats | dark | Terms as numbers, with a source line |
| 7 | Process grid | dark | Method: week 0 to week N, one outcome per step |
| 8 | Stories / founder note | light | Accountability: a named person, in their own words |
| 9 | Offers | light + top hairline | Choice: three offers with fixed prices |
| 10 | Final CTA | dark | The ask: two actions, the legal entity, a launch checklist |
| 11 | Footer | dark | Permanence: legal entity, country, email, link columns |

- Proof (clients, stack, founder) comes BEFORE the service list, never after.
- Every section carries `id`, a band attribute and `aria-labelledby` pointing at a real
  heading; a section with no visible H2 gets a visually hidden one.
- Signals repeat across bands rather than concentrating: the stack appears 4 times, the
  clients 4 times, the two CTAs 5 times, the core promise ("4 weeks") in H1, KPI, stats,
  steps and checklist.

## 2. Bands and rhythm

- Exactly three grounds: cream `#faf9f5`, white `#ffffff` (morph start only), anthracite
  `#1c1c1c`. Sequence: light, light, light->dark, dark, dark, dark, dark, light, light, dark, dark.
- ONE soft transition per page: the first light->dark change is an 800ms crossfade of
  `@property`-registered colour variables, triggered when the case-study section top passes
  78% of the viewport (and reverses on the way up). Every other band change is a hard edge.
- Bands are declared on the section (`data-band="cream|dark|morph"`), which sets semantic
  variables. Components read `--surface`, `--surface-card`, `--fg`, `--fg-3`, `--border`
  and never choose light or dark values themselves.
- Inside a band the steps are small: cream -> cream-dark `#f1eee9` -> bento `#f4f2f0`;
  anthracite -> card `#171717` -> border `#232323`. A card is separated from the ground by
  one fill step plus a 1px line, never a big tone jump.
- Do not raise the band delta between same-family bands or strengthen full-width rules.
  Imperceptible steps are what keep eight bands from reading as page ends (NN/g "false floor").
- One element runs continuously through every band: a 1px dashed rail on each edge of the
  container (`mix-blend-mode: difference`, 25% grey, 1px x 4px, lg+ only, no pointer events).

## 3. Container, gutters, vertical rhythm

- Container 1360px, gutter 24px (text column 1312px at 1440). Mobile card gutter 16px.
- Section padding 80px, 112px from 768px. Hero: top 128/144px, `min-height: 100svh`,
  bottom 64/80px. Final CTA 64/80px so the close reads compact.
- Consecutive sections on the SAME band use reduced padding (32/48px) so they read as one
  run. Full padding only where the band changes. The section above owns the seam; never
  stack two paddings.
- Section head block: eyebrow -> 12px -> dotted rule -> 24px -> H2 -> 16px -> intro ->
  48/64px -> content.

## 4. Tokens

Tokens live in TWO files (the CSS `:root` and the Tailwind `theme.extend`) and change
together. Two layers: raw (`--cream`, `--ink-3`) and semantic per band (`--surface`,
`--fg`, `--border`). A lock, not a sign: a `check:tokens` script fails the build on any
literal hex in components. Even black is a token. Alpha variants come from
`color-mix(in srgb, var(--token) N%, transparent)`, SVG glyphs use `currentColor`, canvas
code reads colours from CSS variables at runtime.

| Group | Light | Dark |
|---|---|---|
| Ground | cream `#faf9f5`, white `#ffffff` | anthracite `#1c1c1c` |
| Card fill | bento `#f4f2f0` (morph), cream-dark `#f1eee9` (cream band) | `#171717` |
| Raised inside card | `#ffffff` | `#222222`, `#2a2a2a` |
| Ink tiers | `#1c1b19` / `#404040` / `#6b6a67` / quiet `#536a5d` / faint `#a1a1a1` | `#ffffff` / `#d4d4d4` / `#a3a3a3` / quiet `#809789` / faint `#6b6b6b` |
| Accent | accent-ink `#1a7654` as text | accent `#34e3a3` |
| Lines | card `rgba(0,0,0,.07)`, inner `.05`, strong `#e5e5e5`, dashed `.15` | `#232323`, `rgba(255,255,255,.08)`, `.2`, dashed `.22` |
| Warm frame (hairline grids) | `#e7e3db` | - |
| Glass | nav `rgba(255,255,255,.95)` | nav `rgba(23,23,23,.9)`, pill `rgba(10,10,10,.9)` |
| Radii | card 6, tile 8, small 4, base 10, button 0, pill 9999 | same |
| Shadows | neutral, low alpha, long offset: `0 24px 60px rgba(28,28,28,.10)`; hover `0 8px 30px rgba(0,0,0,.06)` | `0 30px 70px rgba(0,0,0,.4)` |
| Easing | reveal/morph `cubic-bezier(.16,1,.3,1)`, UI `cubic-bezier(.23,1,.32,1)`, spring `cubic-bezier(.34,1.3,.64,1)` | same |
| Durations | press 160, hover 200, hover-slow 300, reveal 600, morph 800 ms | same |

- Every ink tier is text-safe (>= 4.5:1) on every surface of its side. Tokens that are not
  are named DECORATION ONLY in the token comment and never carry content.
- Accent is a foreground on dark (8.65:1) and decoration only on light (1.43:1). On light,
  meaningful accent text uses accent-ink.
- The grey-green "quiet" tier is the brand accompaniment: it fills the second line of
  every two-tone heading (5.05:1 on light).

## 5. Typography

- One sans (General Sans, variable 200-700) for everything. One mono (Martian Mono 400/600)
  for 10px uppercase tags and data labels ONLY, never eyebrows.
- The wordmark is locked: system sans 24px, weight 300, tracking 0.025em. It never inherits
  the display face and never restyles.
- Weights: 400 body, buttons, nav; 450 H2, card and stat titles; 500 H1, bento titles, stat
  values, quotes; 600 client text marks and footer headings. Nothing above 600. A heavier
  face drops every reference weight by 100.

| Role | Size (mobile / desktop) | Line height / tracking / weight |
|---|---|---|
| Display H1 | 32 / `clamp(2rem, 5.4vw, 3.375rem)` | 1.08 -> 1.04 / -0.04em / 500, `text-wrap: balance` |
| Section H2 | 26 / 38 | 1.15 / -0.02em / 450 |
| Case-study headline | 28 / 34 / 40 | 1.15 / 500 |
| Quote | 30 / 36 / 42 | -0.02em / 500 |
| Stat value / KPI | 36 / 48 | 1 / -0.02em / 500 |
| Bento card title | 20 | 1.18 / -0.02em / 500 |
| Dark card title | 18 | 24-28 / -0.02em / 450 |
| Intro | 18 | 28 / 400, max 672px |
| Body, buttons, nav, eyebrow | 14 | 20 |
| Tag | 10 mono uppercase | 14 / +0.12em |

- Max 3 distinct font sizes per composition (one card, one section head, one viewport),
  not per page. Each module states its three in a comment.
- The largest element in a composition is its message: the stat value outranks its title,
  the H1 outranks everything in the hero.
- Every prose block has a measure cap: intro 672px, quote body 576px, CTA body 448px,
  case copy 544px, footer blurb 34ch, step description 46ch.
- Negative tracking scales with size: -0.04em display and KPI, -0.02em headings, 0 body,
  +0.12em only on uppercase mono tags. Uppercase is reserved for those tags.

### Headlines

- Two-tone heading = one element, two short sentences. Line 1 is the claim in full ink;
  line 2 (`display:block`) is the qualifier in the quiet grey-green. Same size, same tracking.
- Sentence case, full stop at the end, 3 to 5 words per line. Line 2 is a contrast ("Not to
  drag on.", "Not just the website.") or a scope clarifier ("Front to back.").
- The closing sections (founder note, final CTA) drop the second tone: single sentences.

## 6. Components

**Section head.** 12px pixel glyph (accent, aria-hidden) + 14px label in `--fg-3`, gap
12px -> 192px dotted rule (1px, 4px period; 128px short variant in the CTA) -> two-tone H2
-> 18px intro. Left-aligned. Static: section heads do not reveal.

**Buttons.** Square (radius 0), 14px, padding 12x20; small 10x16; nav 7x20. Arrow glyph 14px
nudges 2px on hover. Primary = the band's ink as fill and the band's ground as text, so it
inverts with the band and the morph. Secondary = raised fill + 1px strong border; on dark a
ghost with a white/20 border. Pressables scale to .97 on `:active`. Two CTAs with the same
names everywhere: "Start a project" (primary) and "Book a call" (secondary).

**Solid accent fill means exactly one thing: the primary action.** On durance it is reserved
and used by nothing. No accent buttons, pills or hover fills. Accent as foreground (glyphs,
rules, dots, beam, globe) is the brand tint and unrestricted.

**Pills, eyebrows, tags.** Hero status pill: 18px spinning grain disc + 13px/500 label,
underline grows on hover. Mono tag: 10px uppercase 0.12em, no fill by default. Floating
pill: fixed, bottom 16/24px, radius full, glass, blur 20px; stack marquee + ghost primary +
white secondary; appears after 2.4 viewport heights, hides while the final CTA is on screen.

**Bento cards.** 1 / 2 / 3 columns at 640 / 1024, 16px gap, one card spanning 2. Card: 1px
`--border`, radius 6, `--surface-card` fill; head padding 24/64/16/28; a dot-grid stage with
edge fades. Hover: scale 1.012 + a 1.5px accent beam ring that follows the pointer (masked
border only). The whole card is a real `<button aria-expanded>` so the hover affordance sits
on something focusable.

**Hairline grids and lattices.** Light: 1px hairlines are `gap: 1px` over a warm-frame
parent, not borders. Dark: a 5px lattice, frame and gutters in `--border` around
`--surface-card` cells, square corners. Stats 1/2/4 columns, process 1/2/3.

**Stat tiles.** Padding 24px: 20px accent glyph -> 18px title -> 36/48 value -> 14px unit ->
14px scope -> 14px delta in accent-ink. Glyphs differ per cell as identity, not rank. A
right-aligned 12px "Source:" line under the lattice. Not interactive: no hover.

**Logo strips.** Hero marquee 58s loop, 12%/88% edge mask, marks at 16/20px in `--fg-3`
(never 45% opacity). Trust bento: two labelled groups, "Shipped for" (clients as live text)
and "Built with" (rows by layer, 128px label column, 20px glyph + 13px name). Clients never
share a row with a tool vendor. A client logo is never drawn without permission.

**Founder note.** 50/50 at lg on cream-dark, no border, no radius; text half padding 48x32 ->
64x48; 8px accent dot with ping halo + 14px label; quote at quote size; body capped at 576px;
person row: 44px round headshot + 14px name (500) and role. Unlinked, so no hover affordance.

**Story cards.** 1/2/3 columns, gaps 32 then 40px; white 12px frame, 4:3 image, zoom 1.04
over 700ms; 16px name (600) + 12px industry; 14px description; 12px primary button pinned by
flex-grow; hover shadow pre-drawn on `::after` and faded by opacity.

**Case-study carousel.** Full-bleed scroller aligned to the text column; slides
`calc(100vw - 48px)` x 440, 88vw x 470, `min(1000px, 100vw - 22rem)` x 520; next slide peeks;
radius 0. Two scrims (left-to-right black .78 -> .05, top .28 / bottom .45). Content padding
24/32/40; 24px bold text wordmark, mono tag, 28/34/40 headline in a 544px column, chip pinned
bottom-left. Pager chip with 6px dots (active 32px wide) left, 44x44 square arrows right.

**Footer.** Divider: dotted line | four 12px pixel shapes | dotted line, 32px padding. Grid
2/3/5 columns, 32px gap, 48/64px padding; brand column spans 2: wordmark, 34ch blurb,
`<address>` with legal entity, country, email. 14px everything; headings 600; links `--fg-3`
-> ink on hover; bottom padding 72/88px so the floating pill never covers the last row.

**Fixed header.** Transparent at top; once content scrolls under it, white 95% glass on
light bands and `rgba(23,23,23,.9)` on dark bands, detected per band.

## 7. Trust signals: real terms, never claims

| Signal | Form | Placement |
|---|---|---|
| Fixed price | "Product Audit, €1,500 fixed" | Black strip above the nav, first thing on screen |
| All prices | "From €6,000", "€1,500, fixed", "€3,000 a month" | Offer tiles, one row, near the end |
| Availability | "Taking new projects this quarter" + moving grain disc | Directly above the H1 |
| Named clients | Client names as text marks | Hero marquee, trust bento, case studies, story cards |
| Stack by layer | 5 layers, 25 tools with glyphs | Trust bento middle cell; marquee; chips; pill |
| A real person | Desk photo card + 44px headshot by the quote | Trust bento right cell; founder note |
| Process timeline | Week 0 ... Week 4+ tags; "Week 4 of 4" checklist | Hero card, process grid, final CTA |
| Terms as numbers | 4 weeks, 10+ years, 2 weeks support + source line | Stats lattice |
| Legal entity | "Company OÜ · Country" | Under the final CTA buttons; footer address and copyright |

- Every signal is a term of engagement the visitor can check. Rejected and staying rejected:
  "500+" style counts, "100% production-ready", client outcome percentages, star ratings
  with no third-party source, generated fake people, a "System Status" chip when no status
  page exists, nav chevrons when nothing drops down.
- Mock UI values are decorative, `aria-hidden`, and never read as client claims.

## 8. Grouping and contrast (NN/g, applied)

- Never mute text below 4.5:1 to de-emphasise. Sub-4.5 tokens are decoration only.
- Text over photos gets its own scrim sized to the text block so every line holds 4.5:1
  over the brightest pixel.
- Inside a group, the largest internal gap is smaller than the smallest external gap.
- Whitespace first. A boundary only for heterogeneous members, fixed spacing, or variable
  height. Removal test on every border: delete it, re-render; still clear means decoration.
- Nest by instrument: fill for the outer region, hairlines for subregions, never the same
  border token on two adjacent levels (card 7% line, inner rows 5%).
- A container, hover lift or arrow claims interactivity. Anything not a real focusable link
  or button gets no hover, no arrow, no lift: stats, steps, logo cells, chips stay static.
- Every focusable element gets a designed 2px accent-ink ring, offset 2px, accent on dark.
- Asymmetric, left-aligned sections everywhere; the hero copy block is the one centred
  composition. Do not homogenise in either direction.

## 9. Copy

- Voice: a team ("we", "one team of developers") led by a named founder who speaks in first
  person only inside their own note. Clients and stack are separate groups.
- Sentence case everywhere; headlines end with a full stop; hyphens, commas or the middle
  dot `·`, never long dashes.
- CTA names say what happens and never change. Card CTAs name the real destination.
- Step copy is the client's outcome: "You approve ...", "You get a working preview link".
- Numbers are terms, not results: weeks, prices, years, handoffs. Every price carries its
  unit ("fixed", "a month", "From").
- Eyebrows name the step or the frame, never a slogan: "Step 1 · Design and build".
- Every string comes from a slot in a copy deck; builders paste, never invent. Unconfirmed
  facts carry `[ASSUMED]` or `[OWNER]` until confirmed.

## 10. Assets

| Asset | Use | Size / crop |
|---|---|---|
| 3 warm editorial interiors (oak, cream, sage, 35mm film look, no people, no text) | case slides, story cards | 1920x1280 (3:2) webp; `object-position` tuned per crop |
| Founder's desk by a window | trust bento portrait card, founder note media | 1920x1440 (4:3); cover, zoom 1.03/700ms |
| Founder headshot | 44px avatar | 384x384, face centred in the circle |
| Grain texture | 18px spinning status disc | 1920x1072 |
| Hero loop video + first frame | hero panel ground under a dark veil | 1280x720 h264, seamless ~4s loop, first frame equals last, poster = frame 0 |
| Dot globe | stakes section | canvas, 2300 Fibonacci points, cold -> accent, pointer bulge within 140px |
| Pixel shapes | eyebrow, stat glyphs, footer divider, inside the primary CTA | 12px SVG (20px in stats), 5 shapes |
| Product mocks | bento stages, step stages, CTA checklist | HTML/CSS, aria-hidden, CSS loops |

- Imagery is generated with the Higgsfield CLI, costed on the exact argv first, never
  hand-drawn as a procedural stand-in. Never generate a person; real founder photos only.
- One grade across all photography (warm daylight, oak, cream, sage) so the set reads as
  one company. Models smooth grain; add 4-8% grain in CSS rather than regenerating.
- webp, max 1920px wide; photos q82, textures q92. Serve through the framework's image
  component with `sizes`; decorative photos inside a labelled link get `alt=""`.
- Image hover zoom 1.03 over 700ms (1.04 story cards, 1200ms case slides), only inside an
  `overflow:hidden` frame on an actionable element, hover-gated with a keyboard twin.
