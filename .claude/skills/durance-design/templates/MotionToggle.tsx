'use client';

import { useEffect, useSyncExternalStore } from 'react';

// On-page pause for every looping animation (WCAG 2.2.2). State lives on the DOM as
// data-motion="paused" on .site-root: reveal.css pauses the CSS loops, and JS loops
// (video, canvas, scripted chat) watch the attribute. Remembered per viewer; storage
// failures fall back to "playing". Put it in the footer as a plain text button.
const KEY = 'site-motion';
const getRoot = () => document.querySelector<HTMLElement>('.site-root');

function subscribe(cb: () => void) {
  const root = getRoot();
  if (!root) return () => {};
  const mo = new MutationObserver(cb);
  mo.observe(root, { attributes: true, attributeFilter: ['data-motion'] });
  return () => mo.disconnect();
}
const getSnapshot = () => getRoot()?.getAttribute('data-motion') === 'paused';
const getServerSnapshot = () => false;

function apply(paused: boolean) {
  const root = getRoot();
  if (!root) return;
  if (paused) root.setAttribute('data-motion', 'paused');
  else root.removeAttribute('data-motion');
}

export default function MotionToggle({ className = '' }: { className?: string }) {
  const paused = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  useEffect(() => {
    try {
      if (window.localStorage.getItem(KEY) === 'paused') apply(true);
    } catch {
      /* per-viewer convenience only */
    }
  }, []);

  const toggle = () => {
    const next = !paused;
    apply(next);
    try {
      window.localStorage.setItem(KEY, next ? 'paused' : 'playing');
    } catch {
      /* per-viewer convenience only */
    }
  };

  return (
    <button type="button" className={className} aria-pressed={paused} onClick={toggle}>
      {paused ? 'Play motion' : 'Pause motion'}
    </button>
  );
}
