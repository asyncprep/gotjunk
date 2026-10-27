import { useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';

export default function Login() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);

  async function signIn(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setBusy(false);
    if (error) setMessage({ ok: false, text: error.message });
  }

  async function forgot() {
    if (!email) return;
    await supabase.auth.resetPasswordForEmail(email, { redirectTo: window.location.origin });
    setMessage({ ok: true, text: t('login.resetSent') });
  }

  return (
    <div className="center">
      <form className="card auth-card" onSubmit={signIn}>
        <h1>{t('app.title')}</h1>
        <p className="muted">{t('app.subtitle')}</p>
        {message && <div className={`notice ${message.ok ? 'ok' : 'err'}`}>{message.text}</div>}
        <label>
          {t('login.email')}
          <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          {t('login.password')}
          <input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <div className="row">
          <button className="primary" disabled={busy}>{t('login.submit')}</button>
          <button type="button" className="link right" onClick={forgot}>{t('login.forgot')}</button>
        </div>
      </form>
    </div>
  );
}
