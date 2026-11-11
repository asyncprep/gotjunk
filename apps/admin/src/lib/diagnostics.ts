import i18n from '../i18n';
import type { TicketContext } from './tickets';

/**
 * Small in-memory log the report form attaches to a ticket: the last pages visited and the last
 * script errors. Nothing leaves the browser unless someone sends a report.
 */

const LIMIT = 20;
const pages: { path: string; at: string }[] = [];
const errors: { message: string; at: string }[] = [];
const now = () => new Date().toISOString();
const push = <T>(list: T[], item: T) => {
  list.push(item);
  if (list.length > LIMIT) list.shift();
};
const clip = (s: string, n = 600) => (s.length > n ? `${s.slice(0, n)}…` : s);
const safeJson = (v: unknown) => {
  try { return JSON.stringify(v); } catch { return String(v); }
};

let installed = false;
/** Starts listening for script errors. Called once when the app starts. */
export function installDiagnostics() {
  if (installed || typeof window === 'undefined') return;
  installed = true;
  window.addEventListener('error', (e) => {
    const where = e.filename ? ` (${e.filename.split('/').pop()}:${e.lineno}:${e.colno})` : '';
    push(errors, { message: clip(`${e.message || 'Script error'}${where}`), at: now() });
  });
  window.addEventListener('unhandledrejection', (e) => {
    const r = e.reason as { message?: string } | string | undefined;
    push(errors, { message: clip(`Unhandled: ${typeof r === 'string' ? r : r?.message ?? String(r)}`), at: now() });
  });
  const original = console.error.bind(console);
  console.error = (...args: unknown[]) => {
    try {
      push(errors, { message: clip(args.map((a) => (a instanceof Error ? a.message : typeof a === 'string' ? a : safeJson(a))).join(' ')), at: now() });
    } catch { /* never break logging */ }
    original(...args);
  };
}

export function recordPage(path: string) {
  if (pages.at(-1)?.path === path) return;
  push(pages, { path: clip(path, 300), at: now() });
}

/** Everything the report attaches automatically, shown to the reporter before sending. */
export function collectContext(signedInAs: string): TicketContext {
  const nav = navigator as Navigator & { userAgentData?: { platform?: string } };
  return {
    url: window.location.href,
    userAgent: navigator.userAgent,
    platform: nav.userAgentData?.platform || navigator.platform || '',
    language: navigator.language,
    appLanguage: i18n.language,
    timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    viewport: { width: window.innerWidth, height: window.innerHeight },
    screen: { width: window.screen.width, height: window.screen.height, pixelRatio: window.devicePixelRatio },
    touch: 'ontouchstart' in window || navigator.maxTouchPoints > 0,
    online: navigator.onLine,
    signedInAs,
    recentPages: [...pages],
    consoleErrors: [...errors],
  };
}

/** "Chrome 141 on Windows" from a user-agent string, good enough for a ticket summary. */
export function describeBrowser(ua = ''): string {
  const pick = (re: RegExp) => ua.match(re)?.[1];
  const browser =
    (pick(/Edg\/(\d+)/) && `Edge ${pick(/Edg\/(\d+)/)}`) ||
    (pick(/Firefox\/(\d+)/) && `Firefox ${pick(/Firefox\/(\d+)/)}`) ||
    (pick(/CriOS\/(\d+)/) && `Chrome ${pick(/CriOS\/(\d+)/)} (iOS)`) ||
    (pick(/Chrome\/(\d+)/) && `Chrome ${pick(/Chrome\/(\d+)/)}`) ||
    (pick(/Version\/(\d+).*Safari/) && `Safari ${pick(/Version\/(\d+).*Safari/)}`) ||
    'Unknown browser';
  const os = /iPhone|iPad|iPod/.test(ua) ? 'iOS' : /Android/.test(ua) ? 'Android' : /Windows/.test(ua) ? 'Windows'
    : /Mac OS X/.test(ua) ? 'macOS' : /Linux/.test(ua) ? 'Linux' : 'unknown OS';
  return `${browser} · ${os}`;
}
