import { useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { supabase } from '../lib/supabase';
import { useAuth } from '../lib/auth';

// Shown after following an invite or password-reset link.
export default function SetPassword() {
  const { t } = useTranslation();
  const { clearNeedsPassword } = useAuth();
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);

  async function save(e: FormEvent) {
    e.preventDefault();
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setError(error.message);
      return;
    }
    window.history.replaceState(null, '', window.location.pathname);
    clearNeedsPassword();
  }

  return (
    <div className="center">
      <form className="card auth-card" onSubmit={save}>
        <h1>{t('login.setTitle')}</h1>
        {error && <div className="notice err">{error}</div>}
        <label>
          {t('login.password')}
          <input type="password" autoComplete="new-password" minLength={12} required value={password}
            onChange={(e) => setPassword(e.target.value)} />
          <span className="muted small">{t('login.minLength')}</span>
        </label>
        <button className="primary">{t('login.setSubmit')}</button>
      </form>
    </div>
  );
}
