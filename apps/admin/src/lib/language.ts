import { setLanguage } from '../i18n';
import { supabase } from './supabase';

export type Language = 'fr' | 'en';
export const isLanguage = (v: unknown): v is Language => v === 'fr' || v === 'en';

// A choice made on the sign-in page, kept until someone signs in and it is saved on their account.
const UNSENT_KEY = 'tto.lang.unsent';

/** Switches the app and remembers it in this browser and, when signed in, on the person's account. */
export async function chooseLanguage(lang: Language, signedIn: boolean) {
  setLanguage(lang);
  if (!signedIn) {
    try { localStorage.setItem(UNSENT_KEY, '1'); } catch { /* not critical */ }
    return;
  }
  await saveOnAccount(lang);
}

async function saveOnAccount(lang: Language) {
  const { error } = await supabase.rpc('set_my_language', { p_language: lang });
  if (!error) {
    try { localStorage.removeItem(UNSENT_KEY); } catch { /* fine */ }
  }
}

/** After sign-in: a choice made on the sign-in page wins; otherwise the account's language applies. */
export async function applyAccountLanguage(saved: unknown, current: string) {
  let unsent = false;
  try { unsent = localStorage.getItem(UNSENT_KEY) === '1'; } catch { /* treat as nothing pending */ }
  if (unsent && isLanguage(current)) return saveOnAccount(current);
  if (isLanguage(saved) && saved !== current) setLanguage(saved);
}
