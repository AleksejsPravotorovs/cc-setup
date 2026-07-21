---
title: Frontend Skill Policy – Single Primary Style Skill (SPSS)
team: frontend-skill-policy
status: canonical
version: 1.1
date: 2026-04-28
updated: 2026-07-21
applies_to: every Claude session that touches a frontend / UI / design surface in this user's environment
upstream: research/frontend-skill-inventory.md
downstream: qa/visible-content-checklist.md, devops propagation script (task #3)
---

# Frontend Skill Policy

The harness auto-fires multiple visual skills on the same file (shadcn, ai-elements, react-best-practices, nextjs, agent-browser, plus opt-in art/scroll/SVG/motion lanes). Without a policy, they collide and produce **invisible content**: text the same color as the background, full-screen canvases over the app, sticky scenes hiding modals. This document is the canonical rulebook. Every project that imports it inherits one baseline and one set of dormant lanes.

## 1. Single Primary Style Skill (SPSS)

**Active baseline = `shadcn/ui` + Tailwind.**

This is the only visual skill that auto-applies to every frontend file. `nextjs`, `react-best-practices`, `next-cache-components`, `ai-elements`, `agent-browser`, and `turbopack` may co-fire because they are functional, not stylistic – they do not own colors, typography, or layout primitives. Everything else is **dormant**.

All UI work uses shadcn theme tokens – `bg-background`, `text-foreground`, `border-border`, `bg-primary`, `text-primary-foreground`. **Never inline literal hex into `app/globals.css`, `tailwind.config.*`, or component classNames.** If a design reference specifies `#101828`, redefine the existing shadcn token (`--background`) rather than introducing a parallel `--bg-dark` variable. (This is the C2 fix from the inventory: literal hex defeats `text-foreground` contrast and produces invisible body text on dark heroes.)

## 2. The Dormant Lane

The following skills, libraries, and design references are **OFF by default**. They activate only when the user issues an explicit slash command **or** a keyword from the trigger map in section 4.

| Surface | Why dormant |
|---|---|
| `svg-animations` | Absolute-positioned SVG layers cover card content (C5). |
| `algorithmic-art` | Full-screen p5.js canvas, default z-index 0, no `pointer-events: none` → total UI blackout (C3, HIGH). |
| `libraries/scroll-animations/` (vault drop-in) | Scroll transforms applied to overlay surfaces translate Radix portals off-screen / invert z-index (C1, HIGH). |
| `framer-motion` (Motion v12) | Motion runtime overlap when GSAP or Framer is also present (C8). |
| `GSAP` / `ScrollTrigger` | Same – competing scroll-trigger pinning. |
| `three.js` / WebGL scenes | Full-viewport WebGL canvas hides app content if not pointer-locked. |
| `research/design/scroll-driven-ui-roadmap-template.md` | Sticky scroll scenes set `z-index: 10+` on sections → modal invisible behind sticky scene (C4, HIGH). |
| `research/design/section-transitions-spec.md` | Custom reveal classes with literal `cubic-bezier` and palette overrides. |
| `research/design/scroll-scrubbed-video.md`, `video-smoothing.md` | Scroll-scrubbed hero pattern. |
| `research/design/bold-design-principles.md` | Dark-section design philosophy – reference only, never a default. |
| `research/design/premium-design-system-template.md` | Custom CSS-var palette that overrides shadcn OKLCH tokens (C2). |
| `json-render` | Use `ai-elements` for chat UI; only invoke when explicitly told not to. |
| `v0-dev` | Already prompt-signal-gated; reconcile generated literal Tailwind colors back to shadcn tokens before commit (C7). |

## 3. The "No Auto-Mix" Rule

Invoking skill A does **not** cascade into siblings. If the user says *"animate this SVG"*, only `svg-animations` activates – not `algorithmic-art`, not the scroll-animations library, not Framer Motion. Each effect skill must be invoked by its own keyword or slash command, **independently per task**.

A dormant skill never auto-loads because:
- A neighbor file in the same project already used it.
- A `Skills/<library>.md` index page mentions the library.
- Past `git log` shows the library was once used.

Past presence is not consent. Each session starts dormant.

## 4. Keyword → Skill Activation Map

A dormant skill activates **only** via (a) its slash command, or (b) a strong-signal phrase from the table below. Weak signals (second table) require confirming intent with the user before activation – never auto-activate on a weak match.

### 4a. Strong signals (auto-activate the skill)

| Trigger phrases (user message) | Slash command | Skill activated |
|---|---|---|
| "scroll animation", "scroll trigger", "scroll-pinned section", "scroll-driven section" | `/scroll-animations` | `libraries/scroll-animations/` (vault drop-in) |
| "animate this SVG", "draw the path", "morph the icon", "stroke-dasharray" | `/svg-animations` | `svg-animations` |
| "flow field", "generative art", "create art using code", "p5.js art" | `/algorithmic-art` | `algorithmic-art` |
| "spring animation", "framer motion", "layout animation", "AnimatePresence" | `/framer-motion` | Framer Motion (Skills/Framer-Motion.md reference) |
| "GSAP", "ScrollTrigger", "GSAP timeline" | `/gsap` | GSAP (Skills/GSAP.md reference) |
| "3D scene", "WebGL", "three.js", "shader" | `/three` | Three.js (Skills/Three.js.md reference) |
| "scroll-scrubbed video", "video on scroll" | `/scroll-video` | `research/design/scroll-scrubbed-video.md` |
| "reveal on scroll", "section transition spec" | `/section-transitions` | `research/design/section-transitions-spec.md` |
| "bold design principles", "dark-section design philosophy" | `/design-bold` | `research/design/bold-design-principles.md` |
| "premium design system palette", "custom theme palette" | `/premium-palette` | `research/design/premium-design-system-template.md` |

### 4b. Weak signals (confirm intent before activating)

These phrases are common in routine UI work and do **not** by themselves warrant pulling in an effect skill. Ask the user which lane they mean before activating anything.

| Ambiguous phrase | Possible lanes – clarify with user |
|---|---|
| "smooth motion", "smoother transitions", "feel more polished" | plain CSS transitions / Framer Motion / no skill |
| "particles" | physics demo / `/algorithmic-art` / image-noise / decoration only |
| "timeline" | UI timeline component / `/gsap` GSAP timeline |
| "premium design", "dark hero" | shadcn baseline polish / `/design-bold` / `/premium-palette` |
| "animate this" (no other context) | CSS / Framer Motion / `/svg-animations` |

Absence of a trigger = **stay in shadcn baseline**. Do not pre-emptively offer effects; do not load the design refs as decision input.

## 5. Z-Index Contract

Every fixed/sticky/absolute element belongs to exactly one tier. The **decorative-vs-functional** distinction is non-negotiable: a layer is "decorative" if it has no interactive children (no buttons, links, inputs, or click-to-dismiss behavior) and exists purely for visual effect. Modal scrims, popover overlays, and toasts are functional even when they look like a tinted backdrop.

| Tier | Range | What lives here |
|---|---|---|
| **Background (decorative)** | `z-index ≤ 0` | Full-viewport decorative layers – gradient meshes, p5.js canvases, hero video, particle fields, animated SVG backgrounds. **Required: `pointer-events: none`.** |
| **Chrome** | `1 – 9` (or **`z-50`** for sticky app frame) | Persistent app frame. Sticky `<header>`/`<nav>`/`<aside>` may use `z-50` to coexist with overlays – that is the canonical shadcn pattern and is allowed. Use `1–9` for non-sticky chrome. |
| **Content** | `10 – 19` | Page content, in-flow section dividers, decorative sticky scroll scenes (parallax sections, scroll-pinned hero panels). **Decorative scroll scenes are capped here.** |
| **Overlays** | `20 – 49` | App-controlled overlays built without Radix portals: custom scrims, in-flow drawers. |
| **Toasts / Portals** | `50+` | Radix portals (Dialog, Sheet, Popover, Tooltip default to `z-50`); Sonner / cmdk overlays; toasts often use `z-[100]`. **Functional overlays live here and require `pointer-events: auto`.** |

**Hard rules:**
1. **Decorative** full-viewport layers (no interactive children – particle fields, gradient meshes, scroll-scrubbed video panels, p5.js canvases) covering more than 50% of the viewport in either axis MUST have BOTH `pointer-events: none` AND `z-index ≤ 0`. **Functional overlays are explicitly exempt** – Radix `DialogOverlay` / `SheetOverlay` / `AlertDialogOverlay` / vaul `Drawer` / cmdk command-palette overlays live in the Portals tier, use `pointer-events: auto` so click-outside dismisses, and are correct as shipped. (C3 fix.)
2. **Decorative** sticky scenes (scroll-scrubbed panels, parallax sections, scroll-pinned hero scenes) cap at `z-index ≤ 19`. **Sticky chrome** (sticky app header/nav/footer) may use `z-50` – the shadcn `<header className="sticky top-0 z-50">` pattern is canonical and allowed. The line: chrome is part of the app frame; a decorative scene is part of the content reveal flow. If unsure, ask whether the element still makes sense when the user scrolls past – chrome stays, scenes don't. (C4 fix.)
3. When wrapping any subtree in CSS `transform`, `filter`, or `perspective`, audit Radix portal descendants – these properties create a new stacking context that traps portals. Move the portal target to `<body>` or remove the property from the ancestor. (C4 secondary fix.)

## 6. Conflict Resolution Priority

When two skills disagree about how a component should look:

1. **Layout / structure / animation behavior** → **most-recent-invocation wins.** The latest explicit user request reflects current intent. If the user just said "add a scroll animation here", the scroll-animations skill defines the layout for that surface, even if shadcn's default would be different.
2. **Color / typography / theme tokens** → **earliest-invocation wins.** This is almost always the SPSS baseline (shadcn). Brand consistency outranks per-task style. A scroll-animations request does **not** authorize the scroll skill to swap `--background` or import a new font.
3. **Z-index** → tier table in section 5 is non-negotiable. A skill that wants a higher tier must justify it in a comment AND verify it does not collide with Radix portals.
4. **Tie / ambiguity** → SPSS wins. Stay in shadcn + Tailwind.

## 7. Visible-Content Audit (mandatory before claiming a UI task done)

Run `qa/visible-content-checklist.md` against the dev server before marking any frontend task complete. Five yes/no checks; all must be YES. If any check fails, the task is not done – fix and re-verify.

The checklist is the only thing that catches the failure modes this policy is designed to prevent. Skipping it is equivalent to not following the policy.

## 8. Skills Outside Policy Scope (Known Limitations)

This policy is text in `CLAUDE.md`. The harness loads it as advisory context – it cannot disable plugin-level path-pattern auto-injection. The skills below auto-fire regardless of what this document says.

| Skill | Auto-fires on | What "dormancy" actually means here |
|---|---|---|
| `json-render` (vercel-plugin) | `components/chat/**`, `components/chat-*.tsx`, `components/message*.tsx` | Cannot be suppressed by CLAUDE.md text. Mitigation: when both `json-render` and `ai-elements` are loaded, **prefer `ai-elements` patterns** for chat UI; if `json-render` produces visual chrome, keep styling minimal – do not stack additional effects on top. |
| `knowledge-update` (vercel-plugin) | session start | Always loads. Informational; no styling impact. |
| Auto-loaded session reminders / hot cache | session start | Always loads. Informational. |
| **Functional auto-fire co-load** on any `**/*.tsx` edit: `nextjs` + `next-cache-components` + `react-best-practices` + `agent-browser-verify` | TSX file edits | ~10k tokens injected per edit (C9). These are **functional, not stylistic** – treat their suggestions as reference, not blocking. The no-auto-mix rule (section 3) does NOT extend to functional skills; their co-load is expected. |
| `agent-browser` + `agent-browser-verify` | `next dev`, `pnpm dev`, etc. | Both fire on dev-server start – duplicate browser-verification suggestions. Acceptable, low impact. |

If a future plugin offers a deny-list mechanism (e.g., a `~/.claude/settings.json` skill suppression entry), update this section to point at it.

## 9. Boilerplate for Project CLAUDE.md (devops task #3)

The devops propagation script copies the block below verbatim into each project's `CLAUDE.md` (under a `## Frontend Skill Policy` heading):

```markdown
## Frontend Skill Policy (SPSS)

**Active baseline:** shadcn/ui + Tailwind. Use shadcn theme tokens
(`bg-background`, `text-foreground`, `border-border`, `bg-primary`) – never
inline hex into globals.css, tailwind config, or className strings.

**Dormant by default** – activate only via slash command or explicit keyword:
- `/svg-animations`, `/algorithmic-art`, `/scroll-animations`,
  `/framer-motion`, `/gsap`, `/three`
- `/design-bold`, `/scroll-video`, `/section-transitions`,
  `/premium-palette`

**No auto-mix:** invoking one effect skill does NOT activate siblings.
Functional skills (nextjs, react-best-practices, ai-elements) are exempt
from the no-auto-mix rule and may co-load.

**Z-index contract:** decorative bg ≤ 0 (full-viewport decorative layers
require `pointer-events:none`); chrome 1–9 OR `z-50` for sticky app frame;
content 10–19; overlays 20–49; toasts / Radix portals 50+ (functional
overlays require `pointer-events:auto`). Decorative sticky scenes cap at 19;
sticky chrome (`<header className="sticky top-0 z-50">`) is allowed.

**Conflict resolution:** most-recent invocation wins layout/animation;
earliest invocation (the SPSS baseline) wins color/typography.

**Before claiming a UI task done:** run
`qa/visible-content-checklist.md` – all 5 checks must pass.

Full policy: see `FRONTEND_SKILL_POLICY.md` at the vault root.
```

## 10. Scope and Precedence

This policy sits below user instructions (CLAUDE.md, AGENTS.md, direct requests) and above default skill behavior. If a CLAUDE.md says "use Mantine on this project", Mantine is the SPSS for that project – substitute it everywhere shadcn is named in section 1, keep sections 2–8 unchanged.

This policy does **not** override AGENTS.md `PROMPT-FREE OPERATION PROTOCOL` rules. Both are canonical; they cover different surfaces.

## 11. Revision Trigger

Update this document when:
- A new visual skill is installed that auto-fires on `**/*.tsx` or `app/**`.
- A new HIGH-severity conflict pair is observed in production.
- The SPSS baseline changes (e.g. shadcn → next-forge for new project class).

Version bumps go to `version:` in frontmatter and a one-line entry in the upstream researcher's inventory.

## 12. Expert toolkit and command routing (senior design engineer lane)

These toolchains AUGMENT the SPSS baseline; they never replace it. shadcn theme tokens still rule (section 1), the dormant-lane policy and trigger maps in sections 2-4 still apply, and no impeccable or emil skill may override token discipline: if a toolkit suggests literal hex, a new font, or a palette swap, reconcile back to shadcn tokens before commit. All three toolchains are installed user-level, so every project inherits them.

### 12a. emilkowalski design-engineering skills (`~/.claude/skills/`)

| Skill | Fires when |
|---|---|
| `emil-design-eng` | Building or animating any UI; default craft companion for component polish and animation decisions. |
| `animation-vocabulary` | A motion effect can be described but not named; returns the exact term to spec motion precisely. |
| `review-animations` | Strict review of animation code or a diff; default is flagging, approval is earned. |
| `improve-animations` | Codebase-wide motion audit; produces prioritized implementation plans (read-only on source). |
| `find-animation-opportunities` | Finding what deserves motion and rejecting what must not move; proposes exact values, does not implement. |
| `apple-design` | Apple-grade fluidity: gesture-driven UI, springs, drag/swipe/sheet, momentum, interruptible transitions, translucent depth, reduced motion. |

### 12b. Impeccable command routing

`/impeccable init` once per project (captures PRODUCT.md / DESIGN.md context). Then route by symptom; format `/impeccable <command> <target>`:

| Symptom / need | Command |
|---|---|
| New feature end-to-end | `craft` (plan first with `shape`) |
| Bland / generic design | `bolder` |
| Cluttered / loud | `distill` or `quieter` |
| Pre-ship pass | `polish` then `audit` |
| UX review | `critique` |
| Edge cases / i18n / overflow | `harden` |
| Motion / micro-interactions | `animate` |
| Typography | `typeset` |
| Spacing / rhythm | `layout` |
| Color | `colorize` |
| Unclear copy | `clarify` |
| Responsive behavior | `adapt` |
| Performance | `optimize` |
| First-run / empty states | `onboard` |
| Live browser iteration | `live` |

Color note: `colorize` output must land on shadcn tokens (redefine `--background` etc.), never parallel CSS variables; section 1 wins any conflict.

### 12c. Higgsfield CLI (visual asset generation)

Preferred tool for hero images, product shots, ads, and video assets. Installed at `/opt/homebrew/bin/higgsfield` (aliases `higgs`, `hf`).

- `higgsfield model list [--video]` - list available models
- `higgsfield generate create <model> --prompt "..." [--image <upload_id>]` - create a generation
- `higgsfield generate cost` / `higgsfield generate list` / `higgsfield generate wait` - estimate, track, block until done
- `higgsfield upload` - upload a reference image for image-to-image
- `higgsfield product-photoshoot` - brand-quality product images
- `higgsfield marketing-studio` - ads / marketing assets
- `higgsfield marketplace-cards`, `higgsfield soul-id`, `higgsfield account`

Typical flow: `higgsfield model list` -> `higgsfield generate create <model> --prompt "..."` -> `higgsfield generate wait`. Generated assets are raw material: they enter the UI inside token-disciplined components, never with inline hex sampled from the artwork.
