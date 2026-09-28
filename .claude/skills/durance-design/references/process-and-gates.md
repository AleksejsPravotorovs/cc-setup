# Process and gates: how the durance.dev result was produced

Provenance with commit hashes and `file:line` in
`durance.dev/research/skill-mining/process-lessons.md`. Two reworks happened in 2026:
an invented concept with a custom scroll engine (never shipped as the front page,
589 image credits on the hero alone) and a reference-modelled rebuild by an agent team
(shipped in one day, 21.5 credits). The second is the model.

## 1. The pipeline

1. **Pick ONE concrete reference and write the ask down verbatim.** A reference is a live URL
   you can screenshot AND read the shipped code of. A written concept with no site to measure
   makes every decision an invention and every miss late. Log the owner's words before any spawn.
2. **Scout inline, before any agent exists.** Capture the reference: screenshots at fixed scroll
   steps (desktop 1440x900, mobile 390x844 at DPR 2), page HTML split per section, the
   stylesheet, the JS chunks. **Save the captures IN the repo** (`research/<ref>/shots-ref/`);
   captures left in a scratchpad were gone a week later and the specs could no longer be
   re-checked. Check live tool balances (image credits); never plan spend off a stale note.
3. **Measure the reference into five per-axis specs** with five parallel researchers writing
   disjoint files: `01-layout.md`, `02-tokens.md`, `03-motion.md`, `04-copy.md`, `05-assets.md`.
   Provenance is mandatory: layout numbers from a class or inline style, else tagged
   **(measured)** or **(inferred)**; every contrast ratio computed with WCAG luminance; motion
   items tagged `[EXTRACTED]` / `[SSR]` / `[SHOT]` / `[DESIGN]` (a design item is a proposal,
   not an extraction); every copy string has a slot ID and builders paste, never invent, with
   `[ASSUMED]`, `[ILLUSTRATIVE]`, `[OWNER]` markers. State the brand mapping once (reference
   green -> our accent). Barrier: the build needs all five together.
4. **Take the design rulings, log them, surface them.** Do not ask, do not hide. Each ruling
   goes in `decomposition.md` and reappears for the owner in plain English with an overrule
   phrase: "I took these decisions without asking, so overrule any of them."
5. **Write the section CONTRACT before building.** One file, the whole brief a section builder
   receives. It must contain: the exact files a builder owns and a never-edit list (layout,
   tokens, other sections, production routes); what to do when something shared is missing
   (define locally, report it, never add tokens or inline hex); the page order with ids, bands
   and the spec sections to read; the copy source and the ban on inventing copy; shared
   classes, components and data attributes with exact semantics; behaviour and a11y rules
   restated locally, not by reference; builder-safe verify commands and the build/dev ban
   (parallel builders share one build directory); a structured return format (files touched,
   local classes that look shared, unfilled copy slots, spec departures and why).
6. **Build in an isolated route so production stays live.** New route group with its own
   layout, fonts and token block. Order: scaffold (ONE agent, coherent: layout, page, tokens,
   Tailwind mirror, nav with the locked wordmark, footer, motion controller, pill, section
   registry) -> section agents in parallel on disjoint files (CSS Modules per section, so no
   shared file is ever edited by two agents) -> one integrator.
7. **Filmstrip-compare against the reference, desktop and mobile.** Same tool, same step for
   both sites: scroll by `0.85 x viewport height`, write `<prefix>-NN-y<scrollY>.jpg`, so frame N
   of ours lines up with frame N of the reference. Keep filmstrips in the repo. READ the
   filmstrip: identical byte sizes on consecutive tail frames mean the page was shorter than
   the `scrollHeight` read at load (a flat `content-visibility` placeholder guess).
8. **Adversarial review, then fix.** Lenses: fidelity vs reference shots, animation bar, UI
   doctrine, a11y + reduced motion, mobile. One triage agent per lens, not two refuters per
   finding (that was ~160 agents of overspend). Then parallel fixers and one verifier.
9. **Ship behind the new route; fix owner reports one commit each**, root cause in the body,
   each followed by a snapshot commit.
10. **Cut over with the old page parked.** Move the route group so its layout wraps `/` only;
    old home to `/old` with `robots: { index: false, follow: false }`; permanent redirect from
    the build path; public asset paths unchanged so no URL breaks.

## 2. Gates (exact commands)

**Static.** `npm run lint` (0 errors), `npx tsc --noEmit` (exit 0), `npm run build` (static
pages generated), plus the design lock `bash .claude/skills/durance-design/scripts/check-design.sh`
(no long dashes repo-wide, no literal hex in components). Section builders run only tsc, eslint
on their own file and the design lock. NEVER `next build` or `next dev` from a parallel builder.

**Why not `grep -P`.** macOS ships BSD grep, which has no `-P` and exits 2. Under zsh, PATH may
resolve to GNU grep, so it works interactively and silently checks nothing from a script. The
old gate "reported PASS over 428 violating lines in 36 files". Use perl, enumerating with
`git ls-files`:
```bash
git ls-files -z | xargs -0 perl -CSD -ne 'print "$ARGV:$.:$_" if /[\x{2014}\x{2013}]/; close ARGV if eof'
```

**The visible-content checklist, all 5 checks.** "All 5 checks must pass before any UI task is
reported complete. A check that was not actually run is a failed check. Paste real command
output, not a claim."
1. The gates are green (record exit codes).
2. The content is actually on the page: every section renders visible text; nothing stuck at
   `opacity: 0`; with JavaScript disabled the page still shows its content; no text on a
   background of the same lightness; a canvas is not text, screenshot it and read it; computed
   style is not markup (font registers resolved to nothing for six sessions while every gate
   stayed green, found by screenshot).
3. The z-index contract holds: background layers at 0 carry `pointer-events: none`; content
   10-19; overlays 20-49; toasts 50+; sticky scenes never exceed 19; every interactive element
   is actually clickable.
4. Responsive and reduced motion: 375 / 768 / 1440, no horizontal overflow (`scrollWidth`
   equals the viewport on mobile), reduced motion honoured on every animation and cited by
   line, transform and opacity only.
5. States and accessibility: visible `:focus-visible` on everything, keyboard order sensible,
   forms cover idle / loading / success / error, WCAG AA on every pair, alt text, accessible
   names on icon buttons.
Report as a 5-row table with evidence. "It probably works" is not a result.

**Screenshots.** Real Chrome from `/Applications` over CDP:
`node .claude/skills/durance-design/scripts/shoot-page.mjs <url> <outDir> <prefix> 1440 900`
and `... <prefix>m 390 844 1` for mobile. Chrome for Testing from `~/.cache/puppeteer` hangs
on localhost (macOS Local Network privacy gate that a headless process cannot approve). Wait
for `Page.loadEventFired`, not the `Page.navigate` reply. Shoot the reference and ours with
identical arguments; shoot production again after deploy.

**WebKit for Safari-class bugs.** The ghost pill and the loop seam were Safari-only paint
defects. Verify hide/show and video seams in WebKit, not only Chrome.

**Receipts in the commit body.** Every feat/fix commit lists the gates it ran with results.
Claim done only beside fresh command output; otherwise `EDITED-UNVERIFIED: <file>`.

**Outbound links.** Curl every outbound link at deploy. A placeholder calendar URL shipped and
404ed the primary CTA for months. Placeholders are a launch blocker.

## 3. Lessons: symptom -> root cause -> rule

1. Grey ghost pill at the bottom of the hero (Safari) -> hidden pill was `opacity: 0` with
   `backdrop-filter` always on -> hide with `visibility: hidden`, blur only in the shown state,
   delay the visibility flip past the exit fade.
2. Grey frame pops before playback and at every loop restart -> the poster was a separately
   generated still -> the poster IS the video's frame 0 (`ffmpeg -frames:v 1`).
3. Visible cut at the loop point -> the generator does not guarantee a seamless loop and a JS
   `timeupdate` crossfade lands 0.45-0.7s early -> make the FILE seamless with ffmpeg `xfade`
   (last 25 frames into the first 25); delete the JS seam logic.
4. Old asset still served after the fix -> CDN and image-optimizer caches keyed on the file
   name -> every replaced asset gets a NEW file name.
5. Logo drifted to the new display font -> the contract locked the markup string, not the
   rendering -> "keep the logo" means visual fidelity: capture the rendered CSS from production
   (family, size, weight, tracking, colour) and lock it in one component.
6. Founder portrait as the big card image "distorts the card" -> a half-screen face in a
   featured media slot -> portrait goes to the 44px avatar; the card keeps the workspace photo.
7. Face was "a dot" in the avatar -> `object-fit: cover` of a full portrait in 44px -> get a
   source asset framed for the slot (a square headshot); CSS crops are a stopgap.
8. Clients mixed with the tech stack -> one logo row held both -> separate labelled groups,
   one data list feeding every strip, stack by layer; clients never share a row with a tool.
9. First-person copy undersold the company -> the copy deck followed the old site's solo voice
   while the question was open -> team voice; founder in first person only in their own note;
   mark every voice-dependent line so the swap is one pass.
10. Image-generation spend blowout (48 quoted, 87.2 charged) -> costed without a flag that the
    real command carried -> cost the exact argv, character for character; write it to a file
    once and have `cost` and `create` read it; report actual spend from the transactions list.
11. A whole hero built as a procedural drawing the owner never wanted -> a plan listed
    "procedural" as the DEFAULT for an open owner decision and the session took it silently ->
    a default beside an open decision is not permission when it decides how the work LOOKS:
    state it in the turn it matters, keep building, keep the swap point behind a frozen contract.
12. The custom-engine concept never shipped -> too ambitious (12 routes, 15 sessions), too
    custom (scroll lock, cross-route spine, a 105-check harness to prove it), too expensive,
    too far from the business, and the UX kept needing owner rescue -> copy a proven reference,
    budget the imagery small, build no engine the reference does not have.
13. Frame-rate check failed a page that dropped nothing -> headless Chrome ticks at a steady
    20ms -> calibrate idle vs scrolling on the same tab.
14. Instrumentation said the scroll scene worked; a screenshot said nobody could see it -> the
    pinned scene sat two viewports below the fold -> always screenshot.
15. `scroll-behavior: smooth` fought the scroll library -> it rewrites the value on rAF -> keep
    native scroll; static rule keyed on the route root, in server markup.
16. Font registers resolved to nothing for six sessions, all gates green -> declared on `:root`
    where the framework's `--font-*` variables are not in scope -> assert computed style.
17. Keyframe in a CSS Module silently never animates -> the bundler hashes animation names in
    modules -> global utility class or a local keyframe declaration.
18. 1px light line between two dark bands -> `content-visibility` paints bands in isolation and
    fractional heights leave a gap -> 1px `box-shadow` in the band's own ground.
19. Accent text illegible on cream -> the accent is 1.43:1 on light -> the same hue darkened for
    light grounds (4.82:1), the exact accent only on dark.
20. Text over a full-bleed video unreadable -> transparent type over imagery -> chrome sits on a
    chip surface, off the composition.
21. A play button on a decorative loop -> inline film state added nothing -> the control became
    an arrow link to the contact section.
22. Hover-lift cards that are not links -> affordance without behaviour is a trust defect ->
    link them or remove the lift.
23. A verifier that could not fail -> a "0KB per frame" budget passed because the API reads 0 ->
    measure off disk; negative-test every gate before trusting it.
24. Uncommitted work outlived its session -> eleven files left dirty -> every phase ends green
    AND committed; after a direction change start fresh with a handoff doc.
25. Dead primary CTA for months -> a placeholder URL shipped -> curl every outbound link.

## 4. Standing owner rulings

- **Logo fidelity.** "Keep the logo" means the visual result: typeface, size, weight,
  letter-spacing, colour, not the text string or the markup.
- **No long dashes.** "I do not want to see em-dashes. Not here or in the website." En-dash
  included; chat, plans and every authored file.
- **Assets come from Higgsfield.** "You are a genius in terms of coding and creating stuff, but
  you are not a creative AI in terms of video generation." The generator makes the asset; the
  repo makes the code around it. Never a procedural stand-in.
- **Cost on exact params.** "A cheaper subset is not an estimate, it is a different job."
  Report actual spend, not the estimate.
- **Surface open decisions.** "A default nobody was told about cannot be corrected." Do not
  stop and ask; state it, keep building, pick the cheapest reversible path.
- **One reference.** Design work is measured against the reference screenshots and the
  per-axis specs, not against the previous site.
- **Precedents lend mechanics, not clothes.** From a cited earlier site take the mechanics and
  timings, not the colour, type or geometry.
- **Team voice.** "We are a team of developers, and I'm just a founder, CEO and AI architect."
  Clients and stack never share a row.
- **Real marks only.** Never draw or invent a logo for a real company; the slot stays empty
  until the real mark arrives.
- **Solid accent fill = primary action only. Never mute content below 4.5:1.**

## 5. Team shape (when the work is multi-agent)

- Coordinator keeps: scouting and capture, the rulings, the barrier between phases, the full
  build and screenshots after sections land, owner-report fixes, the cutover.
- Phase 1, understand: five parallel researchers (layout, tokens, motion, copy, assets), disjoint outputs.
- Phase 2, build: one scaffold agent -> section agents on disjoint files -> one integrator.
- Phase 3, review: one triage agent per lens -> fixers -> one verifier.
- The integrator's discoveries (keyframe hashing, placeholder heights) get folded back INTO the
  contract so it stays the single source for later edits.

## 6. Asset production

- Images: `nano_banana_pro`, `--resolution 2k`, 2 credits each. House prompt style: warm
  editorial, oak / cream / sage, "shot on 35mm film", always "no text, no logos, no people".
- Video: `kling3_0_turbo`, 16:9, 5s, 720p, 7.5 credits. Transcode
  `ffmpeg -an -vf scale+crop 1280x720 -c:v libx264 -crf 28 -preset slow -pix_fmt yuv420p -movflags +faststart`,
  then seamless via `xfade` of the last 25 frames into the first 25; poster = frame 0.
- Flow: `hf-cap.sh <model> <args>` (costs the exact argv, refuses above the cap, logs to
  `research/higgsfield-spend.log`) -> download -> `cwebp -q 82` photos, `-q 92` textures,
  `-resize 1920 0`.
- Placement notes for builders: keep the subject in the left third for text overlay, crop
  stray marks with `object-position`, add grain in CSS (`feTurbulence`, 4-8%,
  `pointer-events: none`, z <= 0) because the model smooths noise.
- Failed jobs are refunded; retry once on the same argv. Moderation rejections are refunded.
- Real founder photos are supplied by the owner, never generated.
- Budget small: a whole front page's imagery was 21.5 credits.
