import { useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { dateTime, isAdminRole, must, supabase } from '../lib/supabase';
import { useAction, useLoad } from '../lib/hooks';
import { useAuth } from '../lib/auth';

type Item = {
  item_id: string;
  kind: 'inconsistency' | 'question';
  ref: string;
  area: string;
  priority: 'blocker' | 'pilot' | 'v1b' | 'info';
  title: string;
  detail: string | null;
  spec_refs: string | null;
  blocks: string | null;
  build_default: string | null;
  status: 'open' | 'asked' | 'answered' | 'resolved' | 'deferred';
  answer: string | null;
  answered_at: string | null;
  sort_order: number;
};

const STATUSES = ['open', 'asked', 'answered', 'resolved', 'deferred'] as const;
const PRIORITIES = ['blocker', 'pilot', 'v1b', 'info'] as const;
const DONE = new Set(['answered', 'resolved']);

export default function Project() {
  const { t } = useTranslation();
  const { role } = useAuth();
  const canEdit = isAdminRole(role);
  const items = useLoad(() => must(supabase.from('spec_item').select('*').order('sort_order')) as Promise<Item[]>, []);
  const [kind, setKind] = useState<Item['kind']>('question');
  const [status, setStatus] = useState<'all' | 'todo' | Item['status']>('todo');
  const [priority, setPriority] = useState<'all' | Item['priority']>('all');
  const [search, setSearch] = useState('');

  const all = items.data ?? [];
  const ofKind = all.filter((i) => i.kind === kind);
  const shown = useMemo(() => ofKind.filter((i) =>
    (status === 'all' || (status === 'todo' ? !DONE.has(i.status) && i.status !== 'deferred' : i.status === status))
    && (priority === 'all' || i.priority === priority)
    && (!search.trim() || `${i.ref} ${i.title} ${i.detail ?? ''} ${i.area} ${i.answer ?? ''}`.toLowerCase().includes(search.trim().toLowerCase())),
  ), [ofKind, status, priority, search]);

  // Group by area, keeping the curated order (sort_order) within and across groups.
  const groups = useMemo(() => {
    const map = new Map<string, Item[]>();
    shown.forEach((i) => map.set(i.area, [...(map.get(i.area) ?? []), i]));
    return [...map.entries()];
  }, [shown]);

  const questions = all.filter((i) => i.kind === 'question');
  const issues = all.filter((i) => i.kind === 'inconsistency');
  const openBlockers = all.filter((i) => i.priority === 'blocker' && !DONE.has(i.status)).length;

  const exportCsv = () => {
    const header = ['ref', 'type', 'area', 'priority', 'status', 'title', 'detail', 'spec_refs', 'blocks', 'meanwhile', 'answer'];
    const rows = shown.map((i) => [i.ref, i.kind, i.area, i.priority, i.status, i.title, i.detail, i.spec_refs, i.blocks, i.build_default, i.answer]);
    const csv = [header, ...rows].map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\r\n');
    const url = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
    const a = document.createElement('a');
    a.href = url;
    a.download = `truck-team-os_${kind === 'question' ? 'questions' : 'incoherences'}.csv`;
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <>
      <div className="page-head">
        <h1>{t('project.title')}</h1>
        <div className="row right no-print">
          <button onClick={() => window.print()}>{t('project.print')}</button>
          <button onClick={exportCsv}>{t('common.export')}</button>
        </div>
      </div>

      <div className="tiles" style={{ marginBottom: 16 }}>
        <div className="tile">
          <div className="v">{questions.filter((i) => DONE.has(i.status)).length} / {questions.length}</div>
          <div className="k">{t('project.questionsAnswered')}</div>
        </div>
        <div className="tile">
          <div className="v">{issues.filter((i) => DONE.has(i.status)).length} / {issues.length}</div>
          <div className="k">{t('project.issuesResolved')}</div>
        </div>
        <div className="tile">
          <div className="v" style={{ color: openBlockers ? 'var(--red)' : undefined }}>{openBlockers}</div>
          <div className="k">{t('project.openBlockers')}</div>
        </div>
        <div className="tile">
          <div className="v">{questions.filter((i) => i.status === 'asked').length}</div>
          <div className="k">{t('project.waitingClient')}</div>
        </div>
      </div>

      <div className="tabs no-print" role="tablist">
        {(['question', 'inconsistency'] as const).map((k) => (
          <button key={k} role="tab" aria-selected={kind === k} className={kind === k ? 'on' : ''} onClick={() => setKind(k)}>
            {t(`project.tab_${k}`)} ({all.filter((i) => i.kind === k).length})
          </button>
        ))}
      </div>

      <p className="muted small">{t(kind === 'question' ? 'project.introQuestions' : 'project.introIssues')}</p>

      <div className="row no-print" style={{ marginBottom: 14 }}>
        <div className="chips" style={{ margin: 0 }}>
          {(['todo', 'all', ...STATUSES] as const).map((s) => (
            <button key={s} className={`chip ${status === s ? 'on' : ''}`} onClick={() => setStatus(s)}>
              {t(`project.status_${s}`)}{' '}
              <span className="n">{s === 'all' ? ofKind.length
                : s === 'todo' ? ofKind.filter((i) => !DONE.has(i.status) && i.status !== 'deferred').length
                : ofKind.filter((i) => i.status === s).length}</span>
            </button>
          ))}
        </div>
        <select value={priority} onChange={(e) => setPriority(e.target.value as typeof priority)} aria-label={t('project.priority')}>
          <option value="all">{t('project.priority')} : {t('common.all')}</option>
          {PRIORITIES.map((p) => <option key={p} value={p}>{t(`project.prio_${p}`)}</option>)}
        </select>
        <input type="search" placeholder={t('project.search')} value={search} onChange={(e) => setSearch(e.target.value)} />
      </div>

      {items.error && <div className="notice err">{items.error}</div>}
      {items.loading && !items.data && <p className="muted">{t('common.loading')}</p>}
      {items.data && !shown.length && <div className="card empty">{t('project.empty')}</div>}

      {groups.map(([area, list]) => (
        <section key={area} className="spec-group">
          <h2>{area} <span className="muted small">({list.length})</span></h2>
          {list.map((i) => <SpecCard key={i.item_id} item={i} canEdit={canEdit} onSaved={() => items.reload(true)} />)}
        </section>
      ))}
    </>
  );
}

function SpecCard({ item, canEdit, onSaved }: { item: Item; canEdit: boolean; onSaved: () => void }) {
  const { t, i18n } = useTranslation();
  const action = useAction(onSaved);
  const [answer, setAnswer] = useState<string | null>(null);
  const editing = answer !== null;
  const save = (patch: Partial<Item>, okText = t('ui.saved')) =>
    action.run(() => must(supabase.from('spec_item').update(patch).eq('item_id', item.item_id).select()), okText);

  return (
    <article className={`card spec-card status-${item.status}`}>
      <div className="row">
        <span className="pill ref">{item.ref}</span>
        <span className={`pill prio-${item.priority}`}>{t(`project.prio_${item.priority}`)}</span>
        {canEdit ? (
          <select className="right" value={item.status} disabled={action.busy} aria-label={t('project.statusLabel')}
            onChange={(e) => save({ status: e.target.value as Item['status'] })}>
            {STATUSES.map((s) => <option key={s} value={s}>{t(`project.status_${s}`)}</option>)}
          </select>
        ) : <span className="pill right">{t(`project.status_${item.status}`)}</span>}
      </div>
      <h3>{item.title}</h3>
      {item.detail && <p>{item.detail}</p>}
      <dl className="spec-meta">
        {item.spec_refs && <><dt>{t('project.specRefs')}</dt><dd>{item.spec_refs}</dd></>}
        {item.blocks && <><dt>{t(item.kind === 'question' ? 'project.blocks' : 'project.impact')}</dt><dd>{item.blocks}</dd></>}
        {item.build_default && <><dt>{t(item.kind === 'question' ? 'project.meanwhile' : 'project.handling')}</dt><dd>{item.build_default}</dd></>}
      </dl>

      {editing ? (
        <div className="stack">
          <textarea rows={3} style={{ width: '100%' }} autoFocus value={answer}
            placeholder={t(item.kind === 'question' ? 'project.answerPlaceholder' : 'project.resolutionPlaceholder')}
            onChange={(e) => setAnswer(e.target.value)} />
          <div className="row">
            <button className="go" disabled={action.busy} onClick={async () => {
              const text = answer.trim();
              const ok = await save({
                answer: text || null,
                ...(text && !DONE.has(item.status) ? { status: item.kind === 'question' ? 'answered' : 'resolved' } : {}),
              });
              if (ok) setAnswer(null);
            }}>{t('common.save')}</button>
            <button className="ghost" onClick={() => setAnswer(null)}>{t('common.cancel')}</button>
          </div>
        </div>
      ) : item.answer ? (
        <div className="answer">
          <div className="small muted">
            {t(item.kind === 'question' ? 'project.answer' : 'project.resolution')} · {dateTime(item.answered_at, i18n.language)}
          </div>
          <p>{item.answer}</p>
          {canEdit && <button className="link no-print" onClick={() => setAnswer(item.answer ?? '')}>{t('common.edit')}</button>}
        </div>
      ) : canEdit && (
        <button className="link no-print" onClick={() => setAnswer('')}>
          + {t(item.kind === 'question' ? 'project.addAnswer' : 'project.addResolution')}
        </button>
      )}
    </article>
  );
}
