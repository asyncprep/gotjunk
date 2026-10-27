import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { businessToday, isAdminRole, must, supabase, type Role } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';
import { useAuth } from '../lib/auth';
import { explainError } from '../i18n';

export default function Team() {
  const { t } = useTranslation();
  const [tab, setTab] = useState<'employees' | 'users'>('employees');
  return (
    <>
      <h1>{t('team.title')}</h1>
      <div className="tabs">
        <button className={tab === 'employees' ? 'on' : ''} onClick={() => setTab('employees')}>{t('team.employees')}</button>
        <button className={tab === 'users' ? 'on' : ''} onClick={() => setTab('users')}>{t('team.users')}</button>
      </div>
      {tab === 'employees' ? <Employees /> : <Users />}
    </>
  );
}

function Employees() {
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const { role } = useAuth();
  const canEdit = isAdminRole(role);
  const data = useLoad(async () => ({
    employees: await must(supabase.from('employee').select('*').order('full_name')) as any[],
    current: await must(supabase.from('v_employee_current_rank').select('employee_id, rank_id, effective_from')) as any[],
    ranks: await must(supabase.from('rank').select('rank_id, name_fr, name_en').eq('active', true).order('sort_order')) as any[],
  }), []);
  const action = useAction(data.reload);
  const [draft, setDraft] = useState({ full_name: '', ceridian_id: '', preferred_language: 'fr' });
  const [rankEdit, setRankEdit] = useState<{ employee_id: string; rank_id: string; from: string } | null>(null);

  if (!data.data) return <div className="card muted">{data.error ?? t('common.loading')}</div>;
  const { employees, current, ranks } = data.data;
  const rankName = (id: string | null) => {
    const r = ranks.find((x) => x.rank_id === id);
    return r ? (lang === 'en' ? r.name_en : r.name_fr) : '—';
  };

  return (
    <div className="card">
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{action.notice.text}</div>}
      <div className="table-wrap">
        <table>
          <thead><tr>
            <th>{t('common.name')}</th><th>{t('team.ceridian')}</th><th>{t('team.language')}</th>
            <th>{t('team.rank')}</th><th>{t('team.since')}</th><th>{t('common.active')}</th><th />
          </tr></thead>
          <tbody>
            {employees.map((e) => {
              const cur = current.find((c) => c.employee_id === e.employee_id);
              const editing = rankEdit?.employee_id === e.employee_id ? rankEdit : null;
              return (
                <tr key={e.employee_id} className={e.active ? '' : 'muted'}>
                  <td>{e.full_name}</td>
                  <td>{e.ceridian_id ?? '—'}</td>
                  <td>{e.preferred_language.toUpperCase()}</td>
                  <td>
                    {editing ? (
                      <div className="row">
                        <select value={editing.rank_id} onChange={(ev) => setRankEdit({ ...editing, rank_id: ev.target.value })}>
                          <option value="">…</option>
                          {ranks.map((r) => <option key={r.rank_id} value={r.rank_id}>{lang === 'en' ? r.name_en : r.name_fr}</option>)}
                        </select>
                        <input type="date" value={editing.from} onChange={(ev) => setRankEdit({ ...editing, from: ev.target.value })} />
                        <button className="primary" disabled={!editing.rank_id || action.busy} onClick={() => action.run(async () => {
                          await must(supabase.rpc('set_employee_rank', {
                            p_employee_id: e.employee_id, p_rank_id: editing.rank_id, p_effective_from: editing.from,
                          }));
                          setRankEdit(null);
                        })}>{t('common.save')}</button>
                        <button onClick={() => setRankEdit(null)}>{t('common.cancel')}</button>
                      </div>
                    ) : rankName(cur?.rank_id ?? null)}
                  </td>
                  <td>{cur?.effective_from ?? '—'}</td>
                  <td>{e.active ? t('common.yes') : t('common.no')}</td>
                  <td>{canEdit && !editing && (
                    <div className="row">
                      <button className="link" onClick={() => setRankEdit({ employee_id: e.employee_id, rank_id: '', from: businessToday() })}>{t('team.setRank')}</button>
                      <button className="link" disabled={action.busy} onClick={() => action.run(() => must(supabase.from('employee')
                        .update({ active: !e.active }).eq('employee_id', e.employee_id).select()))}>
                        {e.active ? t('team.deactivate') : t('team.activate')}
                      </button>
                    </div>
                  )}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {canEdit && (
        <div className="row" style={{ marginTop: 12 }}>
          <input placeholder={t('common.name')} value={draft.full_name} onChange={(e) => setDraft({ ...draft, full_name: e.target.value })} />
          <input className="narrow" placeholder={t('team.ceridian')} value={draft.ceridian_id} onChange={(e) => setDraft({ ...draft, ceridian_id: e.target.value })} />
          <select value={draft.preferred_language} onChange={(e) => setDraft({ ...draft, preferred_language: e.target.value })}>
            <option value="fr">FR</option><option value="en">EN</option>
          </select>
          <button className="primary" disabled={!draft.full_name.trim() || action.busy} onClick={() => action.run(async () => {
            await must(supabase.from('employee').insert({
              full_name: draft.full_name.trim(), ceridian_id: draft.ceridian_id.trim() || null, preferred_language: draft.preferred_language,
            }).select());
            setDraft({ full_name: '', ceridian_id: '', preferred_language: 'fr' });
          })}>{t('team.newEmployee')}</button>
        </div>
      )}
    </div>
  );
}

function Users() {
  const { t } = useTranslation();
  const { role, session } = useAuth();
  const canEdit = isAdminRole(role);
  const data = useLoad(async () => ({
    users: await must(supabase.from('app_user').select('*, employee:employee_id(full_name)').order('email')) as any[],
    employees: await must(supabase.from('employee').select('employee_id, full_name').eq('active', true).order('full_name')) as any[],
  }), []);
  const action = useAction(data.reload);
  const [invite, setInvite] = useState({ email: '', role: 'dispatcher' as Role, employee_id: '', can_edit_config: false });

  if (!data.data) return <div className="card muted">{data.error ?? t('common.loading')}</div>;
  const { users, employees } = data.data;

  async function sendInvite() {
    const { data: result, error } = await supabase.functions.invoke('invite-user', {
      body: { ...invite, employee_id: invite.employee_id || null, redirect_to: window.location.origin },
    });
    if (error) {
      const detail = await (error as any).context?.json?.().catch(() => null);
      throw new Error(detail?.error ?? error.message);
    }
    if ((result as any)?.error) throw new Error((result as any).error);
    setInvite({ email: '', role: 'dispatcher', employee_id: '', can_edit_config: false });
  }

  return (
    <div className="card">
      {action.notice && <div className={`notice ${action.notice.ok ? 'ok' : 'err'}`}>{explainError(action.notice.text)}</div>}
      <div className="table-wrap">
        <table>
          <thead><tr>
            <th>{t('team.email')}</th><th>{t('team.role')}</th><th>{t('team.employee')}</th>
            <th>{t('team.configRights')}</th><th>{t('common.active')}</th><th />
          </tr></thead>
          <tbody>
            {users.map((u) => (
              <tr key={u.user_id} className={u.active ? '' : 'muted'}>
                <td>{u.email ?? '—'}</td>
                <td>{t(`role.${u.role}`)}</td>
                <td>{u.employee?.full_name ?? '—'}</td>
                <td>{u.role === 'senior_ops' || u.can_edit_config ? t('common.yes') : t('common.no')}</td>
                <td>{u.active ? t('common.yes') : t('common.no')}</td>
                <td>{canEdit && u.user_id !== session?.user.id && (
                  <button className="link" disabled={action.busy} onClick={() => action.run(() => must(supabase.from('app_user')
                    .update({ active: !u.active }).eq('user_id', u.user_id).select()))}>
                    {u.active ? t('team.deactivate') : t('team.activate')}
                  </button>
                )}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      {canEdit && (
        <>
          <h2 style={{ marginTop: 16 }}>{t('team.invite')}</h2>
          <div className="row">
            <input type="email" placeholder={t('team.email')} value={invite.email} onChange={(e) => setInvite({ ...invite, email: e.target.value })} />
            <select value={invite.role} onChange={(e) => setInvite({ ...invite, role: e.target.value as Role })}>
              {(['dispatcher', 'admin', 'ttm', 'senior_ops'] as Role[]).map((r) => <option key={r} value={r}>{t(`role.${r}`)}</option>)}
            </select>
            {invite.role === 'ttm' && (
              <select value={invite.employee_id} onChange={(e) => setInvite({ ...invite, employee_id: e.target.value })}>
                <option value="">{t('team.employee')}…</option>
                {employees.map((e) => <option key={e.employee_id} value={e.employee_id}>{e.full_name}</option>)}
              </select>
            )}
            {invite.role === 'admin' && (
              <label className="row"><input type="checkbox" checked={invite.can_edit_config}
                onChange={(e) => setInvite({ ...invite, can_edit_config: e.target.checked })} /> {t('team.configRights')}</label>
            )}
            <button className="primary" disabled={!invite.email || action.busy || (invite.role === 'ttm' && !invite.employee_id)}
              onClick={() => action.run(sendInvite, t('team.inviteSent'))}>{t('team.sendInvite')}</button>
          </div>
        </>
      )}
    </div>
  );
}
