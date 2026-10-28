// One-click sign-in for local development only.
// Accounts come from VITE_QUICK_SIGNIN in apps/admin/.env.local (git-ignored), e.g.
//   VITE_QUICK_SIGNIN="Direction|me@example.com|secret;Répartition|dispatch@example.com"
// The password is optional: without it the button only fills in the email.
// Production builds never include this: the DEV check below is false at build time,
// so the value is dropped from the bundle.

export type QuickAccount = { label: string; email: string; password?: string };

export function parseQuickAccounts(raw: string | undefined): QuickAccount[] {
  if (!raw) return [];
  return raw.split(';')
    .map((entry) => entry.split('|').map((part) => part.trim()))
    .filter(([label, email]) => Boolean(label && email && email.includes('@')))
    .map(([label, email, password]) => ({ label, email, password: password || undefined }));
}

export const quickAccounts: QuickAccount[] = import.meta.env.DEV
  ? parseQuickAccounts(import.meta.env.VITE_QUICK_SIGNIN as string | undefined)
  : [];
