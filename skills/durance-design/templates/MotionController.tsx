'use client';

import { useEffect } from 'react';

// durance-design motion controller. Mount ONCE in the root layout; renders nothing.
// Pair with templates/reveal.css (reveal primitive, keyframe library, pause rules) and,
// in the layout, the inline parse-time marker:
//
//   const MARK_JS = "document.currentScript.parentElement.setAttribute('data-js','')";
//   <div className="site-root" suppressHydrationWarning>
//     <script dangerouslySetInnerHTML={{ __html: MARK_JS }} />
//
//   1. Reveal: one IntersectionObserver marks every [data-reveal] with data-revealed
//      once it enters (or was jumped past: top < 0). CSS does the rest.
//   2. Offscreen governor: pauses every .motion-loop more than 300px outside the
//      viewport. Canvas and JS loops pause themselves (watch data-motion too).
//   3. Theme morph (optional): watches [data-morph-trigger] and flips data-theme on
//      the root. Dark once the trigger's top passes ~78% of the viewport and while it
//      is above the viewport; light again only when you scroll back above it.
//
// Native scroll only. Reduced motion is CSS-only (reveal.css). Nothing is written
// per frame; observers only toggle attributes.
const ROOT = '.site-root';

export default function MotionController() {
  useEffect(() => {
    const root = document.querySelector<HTMLElement>(ROOT);
    if (!root) return;
    root.setAttribute('data-js', '');

    const revealIO = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting || e.boundingClientRect.top < 0) {
            e.target.setAttribute('data-revealed', '');
            revealIO.unobserve(e.target);
          }
        }
      },
      { rootMargin: '0px 0px -5% 0px', threshold: 0 },
    );

    const loopIO = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          (e.target as HTMLElement).style.animationPlayState = e.isIntersecting ? '' : 'paused';
        }
      },
      { rootMargin: '300px 0px', threshold: 0 },
    );

    const seen = new WeakSet<Element>();
    const take = (el: Element) => {
      if (seen.has(el)) return;
      seen.add(el);
      if (el.hasAttribute('data-reveal') && !el.hasAttribute('data-revealed')) revealIO.observe(el);
      if (el.classList.contains('motion-loop')) loopIO.observe(el);
    };
    const scan = (scope: Element) => {
      take(scope);
      scope.querySelectorAll('[data-reveal], .motion-loop').forEach(take);
    };
    scan(root);

    const mo = new MutationObserver((mutations) => {
      for (const m of mutations) {
        m.addedNodes.forEach((n) => {
          if (n instanceof Element) scan(n);
        });
      }
    });
    mo.observe(root, { childList: true, subtree: true });

    let morphIO: IntersectionObserver | null = null;
    const trigger = root.querySelector('[data-morph-trigger]');
    if (trigger) {
      morphIO = new IntersectionObserver(
        (entries) => {
          const e = entries[entries.length - 1];
          const next = e.isIntersecting || e.boundingClientRect.top < 0 ? 'dark' : 'light';
          if (root.getAttribute('data-theme') !== next) root.setAttribute('data-theme', next);
        },
        { rootMargin: '0px 0px -22% 0px', threshold: 0 },
      );
      morphIO.observe(trigger);
    }

    return () => {
      revealIO.disconnect();
      loopIO.disconnect();
      mo.disconnect();
      morphIO?.disconnect();
    };
  }, []);

  return null;
}
