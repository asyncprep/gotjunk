import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase, type Role } from './supabase';

type AuthState = {
  session: Session | null;
  role: Role | null;
  canEditConfig: boolean;
  needsPassword: boolean;
  loading: boolean;
  clearNeedsPassword: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

// Invite and password-reset links land here with type=invite|recovery in the URL hash.
const arrivedToSetPassword = /type=(invite|recovery)/.test(window.location.hash);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<Role | null>(null);
  const [canEditConfig, setCanEditConfig] = useState(false);
  const [needsPassword, setNeedsPassword] = useState(arrivedToSetPassword);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session));
    const { data: sub } = supabase.auth.onAuthStateChange((event, s) => {
      setSession(s);
      if (event === 'PASSWORD_RECOVERY') setNeedsPassword(true);
    });
    return () => sub.subscription.unsubscribe();
  }, []);

  useEffect(() => {
    let cancelled = false;
    async function loadRole() {
      if (!session) {
        setRole(null);
        setLoading(false);
        return;
      }
      setLoading(true);
      const { data } = await supabase
        .from('app_user')
        .select('role, can_edit_config, active')
        .eq('user_id', session.user.id)
        .maybeSingle();
      if (cancelled) return;
      setRole(data?.active ? (data.role as Role) : null);
      setCanEditConfig(Boolean(data?.active && (data.role === 'senior_ops' || data.can_edit_config)));
      setLoading(false);
    }
    loadRole();
    return () => {
      cancelled = true;
    };
  }, [session?.user.id]);

  return (
    <AuthContext.Provider
      value={{ session, role, canEditConfig, needsPassword, loading, clearNeedsPassword: () => setNeedsPassword(false) }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth outside AuthProvider');
  return ctx;
}
