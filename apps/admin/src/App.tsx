import { lazy, Suspense, useEffect, useState } from 'react';
import { Navigate, NavLink, Route, Routes } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from './lib/auth';
import { supabase } from './lib/supabase';
import { chooseLanguage, type Language } from './lib/language';
import Login from './pages/Login';
import SetPassword from './pages/SetPassword';
// Pages load on demand so the sign-in screen and first page arrive quickly.
const Board = lazy(() => import('./pages/Board'));
const ShiftReview = lazy(() => import('./pages/ShiftReview'));
const Config = lazy(() => import('./pages/Config'));
const Team = lazy(() => import('./pages/Team'));
const Audit = lazy(() => import('./pages/Audit'));
const TicketList = lazy(() => import('./pages/Tickets').then((m) => ({ default: m.TicketList })));
const TicketPage = lazy(() => import('./pages/Tickets').then((m) => ({ default: m.TicketPage })));
const Payments = lazy(() => import('./pages/Payments'));
const Guides = lazy(() => import('./pages/Guides'));
import Brand from './components/Brand';
import Toasts from './components/Toasts';
import ReportWidget from './components/ReportWidget';

// Open tickets, shown next to "Tickets" in the menu. Refreshes every minute and after any change.
function useOpenTickets(enabled: boolean) {
  const [n, setN] = useState(0);
  useEffect(() => {
    if (!enabled) return;
    let live = true;
    const load = async () => {
      const { count } = await supabase.from('ticket').select('ticket_id', { count: 'exact', head: true })
        .in('status', ['new', 'in_progress', 'waiting']);
      if (live) setN(count ?? 0);
    };
    void load();
    const timer = setInterval(load, 60_000);
    window.addEventListener('tto:tickets', load);
    return () => { live = false; clearInterval(timer); window.removeEventListener('tto:tickets', load); };
  }, [enabled]);
  return n;
}

export default function App() {
  const { t, i18n } = useTranslation();
  const { session, role, loading, needsPassword } = useAuth();
  const openTickets = useOpenTickets(Boolean(session && role && role !== 'ttm'));

  if (needsPassword && session) return <SetPassword />;
  if (!session) return <Login />;
  if (loading) return <div className="loading-screen">{t('common.loading')}</div>;
  if (!role || role === 'ttm') {
    return (
      <div className="center">
        <div className="card auth-card stack">
          <Brand size="large" />
          <p>{t('login.noAccess')}</p>
          <button onClick={() => supabase.auth.signOut()}>{t('nav.signOut')}</button>
        </div>
      </div>
    );
  }

  // The Stripe function only answers administration.
  const canReadStripe = role === 'admin' || role === 'senior_ops';

  return (
    <>
      <Toasts />
      <header className="topbar">
        <Brand />
        <nav>
          <NavLink to="/" end>{t('nav.board')}</NavLink>
          <NavLink to="/config">{t('nav.config')}</NavLink>
          <NavLink to="/team">{t('nav.team')}</NavLink>
          <NavLink to="/audit">{t('nav.audit')}</NavLink>
          {canReadStripe && <NavLink to="/payments">{t('nav.payments')}</NavLink>}
          <NavLink to="/guides">{t('nav.guides')}</NavLink>
          <NavLink to="/tickets">{t('nav.tickets')}{openTickets > 0 && <span className="nav-count">{openTickets}</span>}</NavLink>
        </nav>
        <span className="spacer" />
        <span className="who">{session.user.email} · {t(`role.${role}`)}</span>
        <select
          aria-label="Language"
          value={i18n.language}
          onChange={(e) => void chooseLanguage(e.target.value as Language, true)}
        >
          <option value="fr">FR</option>
          <option value="en">EN</option>
        </select>
        <button onClick={() => supabase.auth.signOut()}>{t('nav.signOut')}</button>
      </header>
      <main>
        <Suspense fallback={<div className="muted">{t('common.loading')}</div>}>
        <Routes>
          <Route path="/" element={<Board />} />
          <Route path="/shift/:shiftId" element={<ShiftReview />} />
          <Route path="/config" element={<Config />} />
          <Route path="/team" element={<Team />} />
          <Route path="/audit" element={<Audit />} />
          <Route path="/tickets" element={<TicketList />} />
          <Route path="/tickets/:number" element={<TicketPage />} />
          <Route path="/project" element={<Navigate to="/tickets" replace />} />
          {canReadStripe && <Route path="/payments" element={<Payments />} />}
          <Route path="/guides" element={<Guides />} />
          <Route path="*" element={<Board />} />
        </Routes>
        </Suspense>
      </main>
      <ReportWidget />
    </>
  );
}
