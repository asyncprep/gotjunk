import { NavLink, Route, Routes } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from './lib/auth';
import { supabase } from './lib/supabase';
import { setLanguage } from './i18n';
import Login from './pages/Login';
import SetPassword from './pages/SetPassword';
import Board from './pages/Board';
import ShiftReview from './pages/ShiftReview';
import Config from './pages/Config';
import Team from './pages/Team';
import Audit from './pages/Audit';

export default function App() {
  const { t, i18n } = useTranslation();
  const { session, role, loading, needsPassword } = useAuth();

  if (needsPassword && session) return <SetPassword />;
  if (!session) return <Login />;
  if (loading) return <div className="center muted">{t('common.loading')}</div>;
  if (!role || role === 'ttm') {
    return (
      <div className="center">
        <div className="card auth-card stack">
          <p>{t('login.noAccess')}</p>
          <button onClick={() => supabase.auth.signOut()}>{t('nav.signOut')}</button>
        </div>
      </div>
    );
  }

  return (
    <>
      <header className="topbar">
        <span className="brand">{t('app.title')}</span>
        <nav>
          <NavLink to="/" end>{t('nav.board')}</NavLink>
          <NavLink to="/config">{t('nav.config')}</NavLink>
          <NavLink to="/team">{t('nav.team')}</NavLink>
          <NavLink to="/audit">{t('nav.audit')}</NavLink>
        </nav>
        <span className="spacer" />
        <span className="who">{session.user.email} · {t(`role.${role}`)}</span>
        <select
          aria-label="Language"
          value={i18n.language}
          onChange={(e) => setLanguage(e.target.value as 'fr' | 'en')}
        >
          <option value="fr">FR</option>
          <option value="en">EN</option>
        </select>
        <button onClick={() => supabase.auth.signOut()}>{t('nav.signOut')}</button>
      </header>
      <main>
        <Routes>
          <Route path="/" element={<Board />} />
          <Route path="/shift/:shiftId" element={<ShiftReview />} />
          <Route path="/config" element={<Config />} />
          <Route path="/team" element={<Team />} />
          <Route path="/audit" element={<Audit />} />
          <Route path="*" element={<Board />} />
        </Routes>
      </main>
    </>
  );
}
