import { useRef, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import Brand from '../components/Brand';
import { quickAccounts, type QuickAccount } from '../lib/quickSignIn';

export default function Login() {
  const { t } = useTranslation();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const passwordInput = useRef<HTMLInputElement>(null);

  async function signInWith(address: string, secret: string) {
    setBusy(true);
    const { error } = await supabase.auth.signInWithPassword({ email: address, password: secret });
    setBusy(false);
    if (error) setMessage({ ok: false, text: error.message });
  }

  async function signIn(e: FormEvent) {
    e.preventDefault();
    await signInWith(email, password);
  }

  function quick(account: QuickAccount) {
    setEmail(account.email);
    if (account.password) {
      signInWith(account.email, account.password);
    } else {
      setPassword('');
      passwordInput.current?.focus();
    }
  }

  async function forgot() {
    if (!email) return;
    await supabase.auth.resetPasswordForEmail(email, { redirectTo: window.location.origin });
    setMessage({ ok: true, text: t('login.resetSent') });
  }

  return (
    <div className="center">
      <form className="card auth-card" onSubmit={signIn}>
        <Brand size="large" />
        <h2>{t('login.title')}</h2>
        {message && <div className={`notice ${message.ok ? 'ok' : 'err'}`}>{message.text}</div>}
        <label>
          {t('login.email')}
          <input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </label>
        <label>
          {t('login.password')}
          <input ref={passwordInput} type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} />
        </label>
        <div className="row">
          <button className="go" disabled={busy}>{t('login.submit')}</button>
        </div>
        <div className="row" style={{ marginTop: 12 }}>
          <button type="button" className="link" onClick={forgot}>{t('login.forgot')}</button>
        </div>
        {import.meta.env.DEV && quickAccounts.length > 0 && (
          <div className="quick-signin">
            <strong>{t('login.quickTitle')}</strong>
            <span className="muted small">{t('login.quickHint')}</span>
            <div className="row">
              {quickAccounts.map((a) => (
                <button key={a.email} type="button" disabled={busy} onClick={() => quick(a)} title={a.email}>
                  {a.label}
                </button>
              ))}
            </div>
          </div>
        )}
      </form>
    </div>
  );
}
