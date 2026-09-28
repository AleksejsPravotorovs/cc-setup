# Motion: animation in almost every block, without a library

Distilled from durance.dev `app/(site)/` (provenance with `file:line` in
`durance.dev/research/skill-mining/motion.md`). No framer-motion, no GSAP, no Lenis.
Everything below is CSS transitions and keyframes, IntersectionObserver, one rAF canvas
and one rAF spring. Ship the controller, the reveal CSS and the keyframe library
verbatim (see `templates/`); section content is per project.

## 0. The three layers

1. **One reveal primitive.** `data-reveal` on any element, driven by one page-level
   IntersectionObserver and pure CSS transitions. Used on every content block.
2. **A keyframe library of ambient loops.** Every infinite animation carries the class
   `motion-loop`, so one governor pauses it offscreen, under reduced motion and under an
   on-page Pause toggle.
3. **Hover-gated micro-interactions** that only ever move `transform` or `opacity`.

Architecture in six lines:
- An inline `<script>` inside the root marks `[data-js]` during HTML parse, before first paint.
- One client component (renders null) owns 3 observers: reveal, loop governor, theme morph,
  plus a MutationObserver for late DOM.
- The reveal CSS block and the keyframe library live in the global stylesheet.
- A footer toggle writes `data-motion="paused"` on the root; CSS and JS loops obey it.
- Sections own local keyframes in their CSS Module (module keyframe names are hashed).
- Canvas and JS loops self-pause via IO, `visibilitychange` and the `data-motion` attribute.

## 1. The reveal system

- **Two-phase JS marker, no flash, readable with JS off.** The inline script sets `data-js`
  on its parent; the controller sets it again on mount (client navigations do not run inline
  scripts). The hidden state exists ONLY under `[data-js]`; the base rule forces visible.
  ```tsx
  const MARK_JS = "document.currentScript.parentElement.setAttribute('data-js','')";
  <div className="site-root" suppressHydrationWarning>
    <script dangerouslySetInnerHTML={{ __html: MARK_JS }} />
  ```
- **One observer for the page, once, with a jumped-past clause.** `rootMargin: '0px 0px -5% 0px'`,
  `threshold: 0`; mark `data-revealed` when `isIntersecting || boundingClientRect.top < 0`, then
  `unobserve`. The `top < 0` clause reveals anything skipped by an anchor jump or a mid-page
  refresh. Content never re-hides on scroll up.
- **Late DOM gets wired.** A MutationObserver on the root scans added subtrees for
  `[data-reveal], .motion-loop`; a WeakSet dedupes.
- **Transition, not keyframes, so it is interruptible.** 600ms, `cubic-bezier(.16,1,.3,1)`,
  24px up by default.
  ```css
  .site-root.site-root [data-reveal] { opacity: 1; transform: none; animation: none; }
  .site-root.site-root[data-js] [data-reveal] {
    --reveal-from: translate3d(0, var(--reveal-y, 24px), 0);
    transition: opacity var(--dur-reveal, 600ms) var(--ease-out-expo),
                transform var(--dur-reveal, 600ms) var(--ease-out-expo);
    transition-delay: calc(var(--i, 0) * var(--stagger, 60ms));
  }
  .site-root.site-root[data-js] [data-reveal]:not([data-revealed]) {
    opacity: 0; transform: var(--reveal-from);
  }
  ```
- **Variants by attribute value:** `""|up` 24px up, `left` -12px x, `right` +12px x, `pop`
  16px + `scale(.96)`, `fade` none. Distances via `data-reveal-distance="5|16|20|24|28|48"`.
  Per-element duration by overriding `--dur-reveal` locally.
- **Stagger is a per-element index, never a parent variable.** `data-reveal-delay="n"` sets
  `--i: n` (1..8), delay = n x 60ms. Change the step per scope (stats use 80ms). A parent
  variable restyles the whole subtree; set it on the element itself.
- **Never put `data-reveal` on an element that owns a transform, opacity or transition**
  (hover lift, carousel, parallax, tilt). Reveal a wrapper. One transform owner per element.
- **Reduced motion = 200ms opacity only, no delay.** Nothing in JS branches on it for reveals.
- **Above the fold never waits on JS.** Hero copy is a CSS mount animation, transform only,
  so the H1 is opaque at first paint and counts for LCP. The hero card runs a mount animation
  800ms + 120ms at desktop; on mobile its inner entrances hold frame 0 until the card reveals.
- **Section heads do not reveal; content blocks do.** Restraint is part of the look.
- **On-page Pause toggle (WCAG 2.2.2).** Footer button with `aria-pressed`; state lives in
  the DOM as `data-motion="paused"` on the root, read with `useSyncExternalStore` over a
  MutationObserver, persisted in `localStorage` inside try/catch. CSS freezes every loop:
  `.site-root[data-motion="paused"] :is(.motion-loop, .marquee-track) { animation-play-state: paused !important }`.
  JS loops watch the attribute. One-shot reveals are unaffected.

## 2. What moves, section by section (the "every block" map)

Legend: E entrance (once), L loop, H hover/focus, S scroll-linked, P pointer-driven.

**Chrome.** S header slides up by the 44px announcement strip once `scrollY >= 50`, transform
240ms. S nav skin (background, border) 300ms, `backdrop-filter: blur(24px) saturate(1.5)`
constant, never animated; skin decided by one IO band probe at y=120, no layout reads on
scroll. H nav indicator: a 1px element `scaleX(width)` + `translate3d`, 220ms; first entry
snaps in place. H skip link `translateY(-160%) -> none` 200ms on focus. Burger press `.97`
160ms. S floating pill: shows past 2.4 viewport heights, hides while the contact section
intersects, `inert` when hidden; enter 420ms spring from `translate3d(-50%, 50px, 0) scale(.9)`,
exit 200/160ms. L pill marquee 70s. S theme morph: 800ms expo on 14 registered colour
properties, trigger IO `rootMargin 0 0 -22% 0`, dark while `isIntersecting || top < 0`
(built-in hysteresis).

**Hero.** E copy rise 20px 700ms expo. E card rise 28px 800ms +120ms. E avatar `scale(.8) -> 1`
600ms +200ms; prompt 5px 800ms +360ms; 46 chart bars `scaleY(0) -> 1` 700ms at `150 + 22i` ms;
knob fade 300ms at `650 + 22i`; tooltip 4px 400ms at `700 + 22i`. L eyebrow grain disc:
irregular 6-stop rotation, 34s ease-in-out. L curtain: 30 hairlines `scaleY` 0-1-0, 5.4s,
delay `85ms * i`. L avatar: 91 dots `scale .5 <-> 1.3`, 2s, delay `0.8s * distance` so it
radiates. L status dots opacity .25 <-> 1, 1.2s, delays 0/.18/.36s. L logo marquee 58s, chip
marquee 28s. L ring `stroke-dasharray 30 14` spin 9s linear. L film: ~4s seamless video.
H eyebrow underline `scaleX(0 -> 1)` from left 250ms. H marquee pauses on hover. H arrow 2px.

**Trust bento.** E whole frame 48px, 700ms. Logo cells are not links: no hover. H link arrow 2px
+ colour 200ms. H portrait photo `scale(1.03)` 700ms.

**Feature bento.** E 8 cells 24px, stagger by column 0/60/120ms = left-to-right sweep. H/focus
card `scale(1.012)` 300ms; beam ring opacity 300ms, a 420px radial at the pointer masked to a
1.5px border; expand glyph strokes +-2px; one-line reveal slides from 100% 280ms with the
`visibility` flip delayed 280ms; mock rows lift -2px 400ms expo, stagger `90ms * r + 40ms` on
ENTER only, exit 150ms all at once. L caret `steps(1)` 1.1s; orb 40s; tiles bob 4px 3.6s with
delay `((r + c) % 5) * 0.3s` (diagonal ripple); connector dash flow 5.5s + accent pulse 2.6s;
sine threads flow `5.5 + 0.6i` s; stack field bob 7px 7s. L scripted chat (JS): hold 1.6s, wait
900, type 38ms/char, hold 380, send, 550, think 1450, answer, 2200, restart; bubble in 12px +
`scale(.96)` 360ms expo; thinking dots 1.2s at 0/.2/.4s. P stack tilt: spring k 70, c 18, m .6,
`rotateY +-15deg`, `rotateX +-11deg`, translate +-26/18px, `perspective 1100px`.

**Case studies.** E whole carousel 24px 600ms. No autoplay. P native scroll with
`scroll-snap-type: x mandatory`; mouse drag disables snap (`[data-dragging]`), a 4px slop
swallows the click, release scrolls to nearest, snap restored on `scrollend` or 700ms.
Programmatic scroll `smooth`, `auto` under reduced motion. H photo `scale(1.03)` 1200ms; CTA
background 200ms + arrow 2px. Pager: a fixed 32px bar `scaleX(w/32)` + `translateX` 260ms,
never `width`. Arrows press `.97`, disabled opacity .4.

**Globe.** E eyebrow, rule, H2, aside at delays 0-3. Connectors draw on `stroke-dashoffset 1 -> 0`
800ms ease-out, delay `200 + 150 * (i % 3)`. Nodes opacity 400ms at `800 + 60i`. Labels +-12px
500ms at `300 + 120 * (i % 3)`. Title pop 1000ms +500ms. L 2300-dot Fibonacci sphere,
`0.0016 rad/frame` dt-normalised (~65s per turn). S greening from six rim anchors with a 60px
soft edge as the section scrolls; green pulse dash offset over the first 65% of progress; title
parallax `16px -> -16px`. P pointer repulsion radius 140px, quadratic push 1.4, spring .045,
damping .9.

**Stats.** E cards 24px, 80ms stagger. Digit roll in CSS, not JS: 0-9 strips `translate3d`
900ms on a `linear()` spring (fallback expo), delay `card * 80 + 120 + digitFromRight * 40` ms;
rests on the final digit without JS. Source line `fade`.

**Process grid.** E six cells, delays `[0,1,2,1,2,3] x 60ms` = diagonal wave. L six pure-CSS
"video" loops, started only on `[data-revealed]` inside `(prefers-reduced-motion: no-preference)`;
base styles ARE the final frame. Periods 7.2 / 8.4 / 6.0 / 7.8 / 6.6s, chart rings 2s, tooltip
12s, co-prime so the grid never pulses in unison. One-shot chart: line draw 1.5s ease-in-out
+0.3s, area `scale(.95)` 0.8s, marker `scale(.6)` 0.3s +0.6s, rings at 600/1270/1930ms.

**Stories and offers.** E featured 24px; three cards 20px at 0/60/120ms. L ping halo `scale(2)`
fade, 1s `cubic-bezier(0,0,.2,1)`, hidden under reduced motion. H card photo `scale(1.04)`
700ms; shadow pre-drawn on `::after`, opacity 300ms; arrow 2px. Offer tile background 200ms.

**Final CTA.** E copy cascade delays 0..5; panel `right` +1; checklist rows 5px at `i + 2`.
L one live-row dot pulse 2s.

**Global controls.** Buttons: colours 200ms, press `scale(.97)` 160ms, arrow 2px hover-gated.
Focus ring 2px outline offset 2px. Footer links colour 200ms.

## 3. Ambient loops that never jump

- **Video loop: first frame equals last, and the poster IS frame 0.** Crossfade the clip's own
  last 25 frames into its first 25 with ffmpeg `xfade`; native `loop` then restarts on an
  identical frame and no JS seam logic is needed. Extract the still under the video from the
  video itself (`ffmpeg -frames:v 1`); a separately generated still had a grey band that popped
  at every restart. Rename both files on every regeneration so CDN and image-optimizer caches
  cannot serve a stale pair.
- **Video playback contract:** `muted loop playsInline preload="metadata" disablePictureInPicture
  tabIndex={-1}`, `video.muted = true` set on the property too; plays only while IO-visible, not
  reduced, not paused.
- **Marquee seam:** the track holds the set twice (second copy `aria-hidden`), animates
  `translateX(-50%)`, spacing is a trailing margin on every item, never `gap` (or the seam is off
  by one gap). Edge mask 14%/86%. Linear timing.
- **Keyframe loops are closed:** `0%, to {}` share a value. Stepped strips append a duplicate of
  the first value so the last step lands where step 0 starts.
- **Reset out of sight:** multi-phase loops fade to low opacity, snap the value across a 0.1%
  keyframe gap, then fade back. Dash impulses start and end off the path.
- **Spread with delays, desync with periods.** Delay by distance (avatar), by index (curtain),
  by `(row + col) % 5` (tiles); co-prime periods across a grid. `animation-fill-mode: backwards`
  keeps delayed items on frame 0 before they start.
- **Script loops (chat):** one async loop, cancelled by a run token plus a timer set; starts at IO
  `threshold .35`; on leave it aborts and restores the FINISHED frame. SSR, no-JS and reduced
  motion all show the finished exchange.
- **Count-up is CSS, not JS:** digit strips, final value as server text plus an sr-only twin,
  tabular safety via a centred strip over a hidden sizer.
- **Canvas loop:** dt-normalised (`k = min(dt, 50) / 16.667`, `pow(0.9, k)` damping) so 120Hz
  does not run 2x; runs only when IO-visible (200px margin), tab visible, not reduced, not
  paused; colours read from CSS custom properties through a probe element, never literals;
  dots bucketed by colour x alpha with one `fill()` per bucket; DPR capped at 2 plus a
  `resolution` media query to catch monitor moves.

## 4. Hover and interaction

- Movement on hover lives inside `@media (hover: hover) and (pointer: fine)`. Colour-only hovers
  may stay ungated. JS pointer effects bail on non-mouse `pointerType`.
- Every hover state has a `:focus-visible` twin, including `:has(.trigger:focus-visible)` for
  stretched-link cards.
- Only actionable things get hover affordances. Non-link logo cells, stat cards and the
  featured story have none.
- The vocabulary is small: arrow nudge 2px, card lift `scale(1.012)` 300ms, photo zoom
  1.03-1.04 over 700ms (1200ms case studies), press `scale(.97)` 160ms, underline `scaleX` from
  left 250ms, beam ring opacity 300ms.
- Stagger on enter only; exit snaps. Enter and exit are asymmetric (pill 420/200ms).
- Pointer-follow effects: cache the rect on enter, drop it on scroll, rAF-coalesce, write
  custom properties on the smallest element (the beam, not the card). Spring tilt stops its
  rAF when settled and clears the inline transform at rest.
- Shadows fade via a pre-drawn `::after` opacity, never a `box-shadow` transition.

## 5. Performance and correctness

- Animate `transform` and `opacity` only. Colour transitions are allowed for state and the
  morph; `stroke-dashoffset` only for draw-ons. No `transition: all`. Never animate `width` or
  `left`: the nav indicator and pager use scaled 1px/32px elements.
- Durations: UI state 150-300ms (hover 200, press 160, lift 300); reveals 500-1000ms; morph
  800ms; photo zoom 700-1200ms; loops run seconds. UI under 300ms; reveals and ambient may be
  longer.
- Nothing appears from `scale(0)`: markers start at `.6`, avatars at `.8`, pop at `.96`. Line
  growth from an anchor (`scaleY(0)` bars, curtain) is the exception.
- `will-change` exactly once, on the rAF-driven tilt layer. Do not sprinkle it.
- **Hide with `visibility`, delayed past the exit fade.** Safari paints an `opacity: 0`
  element's `backdrop-filter` as a grey ghost. Apply the blur only in the shown state:
  ```css
  .pill { opacity: 0; visibility: hidden;
    transition: transform 200ms, opacity 160ms, visibility 0s linear 200ms; }
  .pill[data-shown="true"] { opacity: 1; visibility: visible;
    backdrop-filter: blur(20px); transition: transform 420ms, opacity 240ms, visibility 0s; }
  ```
  Pair with `inert` for anything focusable.
- **Governor:** every infinite animation carries `motion-loop`; one IO with
  `rootMargin: '300px 0px'` sets inline `animation-play-state: paused` offscreen.
  `animation-play-state` does not inherit, so a composite mock tags its container and forces
  `* { animation-play-state: inherit }` at higher specificity to pause the whole timeline together.
- **Reduced motion is uniform and designed per element:** movement removed, opacity and
  colour kept at 150-200ms, loops paused, canvases draw on change only. Check the frozen
  frame: where frame 0 is meaningless use `animation: none` so the rest frame shows. Better,
  declare loops only inside `no-preference` and make base styles the final frame. The morph
  under reduced motion is 150ms, never 10ms.
- **No layout shift:** reveals are transform-only; `content-visibility: auto` on every
  below-fold section with MEASURED `contain-intrinsic-size` per section (a flat 900px guess
  made the page 11.2k px instead of 17.3k); a 1px band-coloured box-shadow seals subpixel
  seams between isolated bands.
- **CSS Modules hash keyframe names.** A module cannot call a global keyframe by name.
  Declare local copies or use global utility classes (`.anim-dot-pulse`, `.anim-ping`,
  `.anim-spin`, `.anim-blink`).
- **Scope expensive transitions narrowly.** The morph transition on the root restyled ~2,780
  nodes per frame; on the morphing sections only it is ~724. Register transitioned custom
  properties with `@property` or they snap.
- Observers over scroll listeners. Where a listener is needed it is passive and
  rAF-coalesced, writing to refs or the DOM, never React state per frame.
- z-index contract: content 10, rails 20 with `pointer-events: none`, scrim 49, header and
  pill 50, skip link 60. Sections never exceed 19.

## 6. What the old approach did wrong (and the shipped one fixed)

| Concern | Old controller | Shipped controller |
|---|---|---|
| Trigger | scroll + resize listeners, `getBoundingClientRect` per node, re-checks on timers | one IO, unobserve on reveal: zero layout reads during scroll |
| No-JS | `html.js` server-rendered, so content hidden without JS until a 1700ms timer | hidden only under `data-js` set by an inline script: correct by construction |
| Animation | keyframe 0.9s 26px | transition 600ms 24px, variants, interruptible |
| Parallax | hero rAF loop runs forever | none on the hero; scroll parallax only on the globe title, IO-gated |
| Tilt | inline `transition .5s`, no pointer-type gate | spring rAF that stops when settled, mouse-only, off under reduced motion |
| Reduced motion | read once at mount | CSS media queries plus `change` listeners in JS |
| User pause | body attribute only | persisted toggle; loops and JS obey |

## 7. What the scroll-video attempt taught

A pinned, scroll-scrubbed hero on Lenis + GSAP ScrollTrigger with a cross-route SVG spine was
built and did not ship as the front page.
- Instrumentation is not a render. Pin, progress and pixel counts all passed while the scene
  sat two viewports below the fold. A canvas cannot be reviewed by reading it.
- Scroll libraries fight the platform: `scroll-behavior: smooth` on `html` beat two fixes
  because ScrollTrigger rewrites it inline. Keep native scroll; set `scroll-behavior: auto`
  under reduced motion.
- Pin length is circular if measured; scroll-jacking needed four guardrails (skip link, Esc,
  hint, no pin under reduced motion). The shipped page has no pins at all.
- Generated video beats procedural drawing; that survived as the ~4s seamless hero loop,
  played, not scrubbed.
- `addColorStop(1, 'transparent')` is transparent black. Canvases read real colours from tokens.
- Section transition kits (waves, clip-path, skew) were not used: bands meet on hard edges or
  the one 800ms colour morph.

## 8. Motion vocabulary

| Name | Purpose | Duration | Easing | Amount |
|---|---|---|---|---|
| reveal-up | content glide-in, once | 600ms (700 hero copy, 800 hero card) | `.16,1,.3,1` | 24px (5/16/20/28/48) |
| reveal-side | labels, side panels | 500-600ms | `.16,1,.3,1` | +-12px x |
| reveal-pop | centred titles | 600-1000ms | `.16,1,.3,1` | 16px + scale .96 |
| stagger | siblings | +60ms per step (80 stats, 22 bars, 90 rows, 120 labels) | - | - |
| morph | light to dark | 800ms (150 reduced) | `.16,1,.3,1` | 14 colour props |
| header-slide | strip collapse | 240ms | `.23,1,.32,1` | -44px |
| pill-in / out | floating CTA | 420 / 200ms | `.34,1.3,.64,1` / `.23,1,.32,1` | 50px + scale .9 |
| hover-colour | links, buttons | 200ms | `.23,1,.32,1` | - |
| arrow-nudge | link arrows | 200ms | `.23,1,.32,1` | 2px x |
| press | every pressable | 160ms | `.23,1,.32,1` | scale .97 |
| card-lift | bento cards | 300ms | `.23,1,.32,1` | scale 1.012 |
| photo-zoom | image links | 700ms (1200 cases) | `.23,1,.32,1` | scale 1.03-1.04 |
| underline | eyebrow link | 250ms | `.23,1,.32,1` | scaleX 0 to 1 |
| row-lift | mock rows on hover | 400ms in / 150 out | `.16,1,.3,1` | -2px, +90ms each |
| digit-roll | stats | 900ms | `linear()` spring | 0 to n cells |
| draw-on | SVG lines | 800ms (chart 1.5s) | ease-out | dashoffset 1 to 0 |
| marquee | logo strips | 58s / 28s / 70s | linear | -50% |
| bob | tiles, fields | 3.6s / 7s | ease-in-out | 4px / 7px |
| pulse / ping | live dots | 1.2-2s / 1s | ease-in-out / `0,0,.2,1` | opacity .25-1 / scale 2 |
| spin | rings, discs | 9s / 34-40s | linear / ease-in-out | 360deg |
| globe | ambient sphere | ~65s per turn | dt-normalised | 0.0016 rad/frame |
| video | hero film | ~4s loop | - | frame 0 = frame N |

## 9. Portable checklist

- [ ] Inline parse-time script marks the root `data-js`; hidden states only under it; verify with JS disabled.
- [ ] One controller: reveal IO (`-5%` bottom, once, `top < 0` clause), loop governor IO (`300px`), MutationObserver for late nodes.
- [ ] Reveal = transition on opacity + transform, variants by attribute, stagger by per-element index.
- [ ] Every infinite animation has `motion-loop`; closed keyframes; seamless seams.
- [ ] On-page Pause toggle; every JS loop watches it, IO, `visibilitychange` and reduced motion.
- [ ] Hover movement gated to fine pointers, `:focus-visible` twin, only on actionable elements.
- [ ] Reduced motion checked per element in DevTools emulation; frozen frames meaningful.
- [ ] Hide with `visibility` + delayed flip; `backdrop-filter` only when shown; `inert` when hidden.
- [ ] Above-the-fold entrances are CSS mount animations, transform-only on the LCP element.
- [ ] Look at screenshots (and WebKit) before claiming done; instrumentation is not a render.
