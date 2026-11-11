import { Fragment, useMemo, useState, type ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import type { TFunction } from 'i18next';
import { FilePicker, FileList } from '../components/TicketFiles';
import { describeBrowser } from '../lib/diagnostics';
import { useAction, useLoad } from '../lib/hooks';
import { dateTime, must, supabase } from '../lib/supabase';
import {
  OPEN_STATUSES, TICKET_AREAS, TICKET_PRIORITIES, TICKET_STATUSES, TICKET_TYPES, openReport, ticketsChanged,
  type Attachment, type Ticket, type TicketComment, type TicketPriority, type TicketStatus, type TicketType,
} from '../lib/tickets';

const ago = (iso: string, t: TFunction, lang: string) => {
  const s = (Date.now() - Date.parse(iso)) / 1000;
  if (s < 60) return t('tickets.justNow');
  if (s < 3600) return t('tickets.minAgo', { n: Math.floor(s / 60) });
  if (s < 86400) return t('tickets.hAgo', { n: Math.floor(s / 3600) });
  if (s < 86400 * 30) return t('tickets.dAgo', { n: Math.floor(s / 86400) });
  return dateTime(iso, lang);
};

const Badge = ({ kind, value, t }: { kind: 'status' | 'prio' | 'type'; value: string; t: TFunction }) => (
  <span className={`pill t-${kind}-${value}`}>{t(`tickets.${kind}_${value}`)}</span>
);

/* ---------------- list ---------------- */

const TABS = ['open', 'new', 'in_progress', 'waiting', 'closed', 'all'] as const;
type Tab = (typeof TABS)[number];
const inTab = (tab: Tab, s: TicketStatus) =>
  tab === 'all' || (tab === 'open' ? OPEN_STATUSES.includes(s) : tab === 'closed' ? s === 'done' || s === 'wont_do' : s === tab);

export function TicketList() {
  const { t, i18n } = useTranslation();
  const [tab, setTab] = useState<Tab>('open');
  const [type, setType] = useState<'' | TicketType>('');
  const [priority, setPriority] = useState<'' | TicketPriority>('');
  const [area, setArea] = useState('');
  const [q, setQ] = useState('');
  const list = useLoad(async () => {
    const [tickets, comments] = await Promise.all([
      must(supabase.from('ticket').select('*').order('number', { ascending: false }).limit(1000)) as Promise<Ticket[]>,
      must(supabase.from('ticket_comment').select('ticket_id').eq('kind', 'comment').limit(10000)) as Promise<{ ticket_id: string }[]>,
    ]);
    const counts = new Map<string, number>();
    comments.forEach((c) => counts.set(c.ticket_id, (counts.get(c.ticket_id) ?? 0) + 1));
    return tickets.map((x) => ({ ...x, comments: counts.get(x.ticket_id) ?? 0 }));
  }, []);

  const all = list.data ?? [];
  const filtered = useMemo(() => {
    const words = q.trim().toLowerCase();
    return all.filter((x) => (!type || x.type === type) && (!priority || x.priority === priority) && (!area || x.area === area)
      && (!words || `#${x.number} ${x.title} ${x.description} ${x.reporter_name} ${x.reporter_email}`.toLowerCase().includes(words)));
  }, [all, type, priority, area, q]);
  const rows = filtered.filter((x) => inTab(tab, x.status));

  return (
    <>
      <div className="page-head">
        <div>
          <h1>{t('tickets.title')}</h1>
          <p className="muted small" style={{ margin: '4px 0 0' }}>{t('tickets.intro')}</p>
        </div>
        <div className="row right no-print">
          <button onClick={() => openReport('question')}>{t('tickets.newQuestion')}</button>
          <button onClick={() => openReport('suggestion')}>{t('tickets.newSuggestion')}</button>
          <button className="primary" onClick={() => openReport('bug')}>{t('tickets.newBug')}</button>
        </div>
      </div>

      <div className="tabs" role="tablist">
        {TABS.map((k) => (
          <button key={k} role="tab" aria-selected={tab === k} className={tab === k ? 'on' : ''} onClick={() => setTab(k)}>
            {t(`tickets.tab_${k}`)} <span className="muted">({filtered.filter((x) => inTab(k, x.status)).length})</span>
          </button>
        ))}
      </div>

      <div className="row" style={{ marginBottom: 14 }}>
        <input type="search" style={{ flex: '1 1 220px' }} value={q} onChange={(e) => setQ(e.target.value)}
          placeholder={t('tickets.search')} aria-label={t('tickets.search')} />
        <select value={type} onChange={(e) => setType(e.target.value as '' | TicketType)} aria-label={t('tickets.type')}>
          <option value="">{t('tickets.allTypes')}</option>
          {TICKET_TYPES.map((x) => <option key={x} value={x}>{t(`tickets.type_${x}`)}</option>)}
        </select>
        <select value={priority} onChange={(e) => setPriority(e.target.value as '' | TicketPriority)} aria-label={t('tickets.priority')}>
          <option value="">{t('tickets.allPriorities')}</option>
          {TICKET_PRIORITIES.map((x) => <option key={x} value={x}>{t(`tickets.prio_${x}`)}</option>)}
        </select>
        <select value={area} onChange={(e) => setArea(e.target.value)} aria-label={t('tickets.area')}>
          <option value="">{t('tickets.allAreas')}</option>
          {TICKET_AREAS.map((x) => <option key={x} value={x}>{t(`tickets.area_${x}`)}</option>)}
        </select>
      </div>

      {list.error && <div className="notice err">{list.error}</div>}
      {list.loading && !list.data && <p className="muted">{t('common.loading')}</p>}
      {list.data && !rows.length && <div className="card empty">{t('tickets.empty')}</div>}
      {rows.length > 0 && (
        <ul className="card ticket-list">
          {rows.map((x) => (
            <li key={x.ticket_id}>
              <Link to={`/tickets/${x.number}`}>
                <span className="ticket-line">
                  <span className="muted mono">#{x.number}</span> <b>{x.title}</b>
                </span>
                <span className="row small muted">
                  <Badge kind="type" value={x.type} t={t} />
                  <Badge kind="status" value={x.status} t={t} />
                  <Badge kind="prio" value={x.priority} t={t} />
                  <span>{t(`tickets.area_${x.area}`, { defaultValue: x.area })}</span>
                  <span>· {x.reporter_name || x.reporter_email}</span>
                  <span title={dateTime(x.created_at, i18n.language)}>· {ago(x.created_at, t, i18n.language)}</span>
                  {x.attachments.length > 0 && <span>· {t('tickets.nFiles', { count: x.attachments.length })}</span>}
                  {x.comments > 0 && <span className="right">{t('tickets.nComments', { count: x.comments })}</span>}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </>
  );
}

/* ---------------- one ticket ---------------- */

/** Plain-text version of a ticket, to paste into a chat with a developer (or an AI assistant). */
function asText(x: Ticket, comments: TicketComment[], t: TFunction, lang: string) {
  const c = x.context ?? {};
  const lines = [
    `#${x.number} [${t(`tickets.type_${x.type}`)} · ${t(`tickets.prio_${x.priority}`)} · ${t(`tickets.status_${x.status}`)}] ${x.title}`,
    `${t('tickets.area')}: ${t(`tickets.area_${x.area}`, { defaultValue: x.area })}`,
    `${t('tickets.page')}: ${x.page_url || c.url || '-'}`,
    `${t('tickets.reportedBy', { who: x.reporter_email || x.reporter_name, when: dateTime(x.created_at, lang) })}`,
    '',
    `${t(`tickets.describe_${x.type}`)}`,
    x.description,
  ];
  if (x.steps) lines.push('', `${t('tickets.steps')}:`, x.steps);
  if (x.expected) lines.push('', `${t('tickets.expected')}`, x.expected);
  if (x.frequency) lines.push('', `${t('tickets.frequency')} ${t(`tickets.freq_${x.frequency}`)}`);
  if (x.reason) lines.push('', `${t(x.type === 'question' ? 'tickets.whyAsk' : 'tickets.why')}`, x.reason);
  if (x.attachments.length) lines.push('', `${t('tickets.files')}:`, ...x.attachments.map((a) => `- ${a.name}`));
  if (c.userAgent) {
    lines.push('', 'Environment:', `- ${describeBrowser(c.userAgent)} (${c.userAgent})`,
      `- Window ${c.viewport?.width}×${c.viewport?.height}, screen ${c.screen?.width}×${c.screen?.height} @${c.screen?.pixelRatio}x, touch ${c.touch ? 'yes' : 'no'}`,
      `- Language ${c.appLanguage} (browser ${c.language}), time zone ${c.timezone}`);
  }
  if (c.recentPages?.length) lines.push('', 'Recent pages:', ...c.recentPages.map((p) => `- ${p.at} ${p.path}`));
  if (c.consoleErrors?.length) lines.push('', 'Errors:', ...c.consoleErrors.map((e) => `- ${e.at} ${e.message}`));
  const said = comments.filter((m) => m.kind === 'comment');
  if (said.length) lines.push('', `${t('tickets.comments')}:`, ...said.map((m) => `- ${m.author_name || m.author_email} (${dateTime(m.created_at, lang)}): ${m.body}`));
  return lines.join('\n');
}

function Block({ title, children, mono }: { title: string; children: ReactNode; mono?: boolean }) {
  return (
    <section className="ticket-block">
      <h3>{title}</h3>
      <div className={mono ? 'mono' : undefined}>{children}</div>
    </section>
  );
}

/** One line of the trail: "Status: New → Done". Title changes don't repeat the text. */
function eventText(m: TicketComment, t: TFunction) {
  const f = m.event_field ?? '';
  const label = (v: string | null) => {
    if (v == null) return '—';
    const key = f === 'priority' ? `tickets.prio_${v}` : `tickets.${f}_${v}`;
    return t(key, { defaultValue: v });
  };
  if (f === 'title') return t('tickets.ev_title');
  return `${t(`tickets.ev_${f}`, { defaultValue: f })} : ${label(m.event_from)} → ${label(m.event_to)}`;
}

export function TicketPage() {
  const { number } = useParams();
  const { t, i18n } = useTranslation();
  const lang = i18n.language;
  const data = useLoad(async () => {
    const ticket = await must(supabase.from('ticket').select('*').eq('number', Number(number)).maybeSingle()) as Ticket | null;
    if (!ticket) return null;
    const comments = await must(supabase.from('ticket_comment').select('*').eq('ticket_id', ticket.ticket_id)
      .order('created_at').order('comment_id')) as TicketComment[];
    return { ticket, comments };
  }, [number]);
  const reload = data.reload;
  const action = useAction(async () => { await reload(true); ticketsChanged(); });
  const [copied, setCopied] = useState(false);
  const [body, setBody] = useState('');
  const [files, setFiles] = useState<Attachment[]>([]);
  const [uploading, setUploading] = useState(false);

  if (data.loading && !data.data) return <p className="muted">{t('common.loading')}</p>;
  if (data.error) return <div className="notice err">{data.error}</div>;
  if (!data.data) return <div className="card empty">{t('tickets.notFound')} <Link to="/tickets">{t('tickets.allTickets')}</Link></div>;
  const { ticket: x, comments } = data.data;
  const c = x.context ?? {};
  const page = x.page_url || c.url;
  const patch = (p: Partial<Ticket>) => action.run(() => must(supabase.from('ticket').update(p).eq('ticket_id', x.ticket_id).select()), t('ui.saved'));
  const comment = () => action.run(async () => {
    await must(supabase.from('ticket_comment').insert({ ticket_id: x.ticket_id, body: body.trim(), attachments: files }).select());
    setBody('');
    setFiles([]);
  });

  return (
    <>
      <Link to="/tickets" className="small">← {t('tickets.allTickets')}</Link>
      <div className="page-head" style={{ marginTop: 10 }}>
        <div style={{ minWidth: 0 }}>
          <p className="muted small" style={{ margin: 0 }}>{t(`tickets.type_${x.type}`)} <span className="mono">#{x.number}</span>{x.spec_ref && <> · {t('tickets.fromProject', { ref: x.spec_ref })}</>}</p>
          <h1 style={{ marginTop: 4 }}>{x.title}</h1>
          <p className="muted small" style={{ margin: '4px 0 0' }}>
            {t('tickets.reportedBy', { who: x.reporter_name || x.reporter_email || '—', when: dateTime(x.created_at, lang) })}
            {x.resolved_at && <> · {t('tickets.closedOn', { when: dateTime(x.resolved_at, lang) })}</>}
          </p>
        </div>
        <button className="right no-print" onClick={() => {
          void navigator.clipboard.writeText(asText(x, comments, t, lang));
          setCopied(true);
          setTimeout(() => setCopied(false), 1500);
        }}>{copied ? t('tickets.copied') : t('tickets.copy')}</button>
      </div>

      <div className="ticket-grid">
        <div>
          <div className="card stack">
            {page && <p className="small" style={{ margin: 0 }}><span className="muted">{t('tickets.page')} : </span><a href={page} target="_blank" rel="noreferrer" className="break">{page}</a></p>}
            <Block title={t(`tickets.describe_${x.type}`)}>{x.description || '—'}</Block>
            {x.steps && <Block title={t('tickets.steps')} mono>{x.steps}</Block>}
            {x.expected && <Block title={t('tickets.expected')}>{x.expected}</Block>}
            {x.frequency && <Block title={t('tickets.frequency')}>{t(`tickets.freq_${x.frequency}`)}</Block>}
            {x.reason && <Block title={t(x.type === 'question' ? 'tickets.whyAsk' : 'tickets.why')}>{x.reason}</Block>}
            {x.attachments.length > 0 && <Block title={t('tickets.files')}><FileList items={x.attachments} /></Block>}
          </div>

          <div className="card">
            <h2>{t('tickets.activity')}</h2>
            <ol className="ticket-activity">
              {comments.length === 0 && <li className="muted small">{t('tickets.noComments')}</li>}
              {comments.map((m) => m.kind === 'event' ? (
                <li key={m.comment_id} className="event small muted">
                  <b>{m.author_name || m.author_email || '—'}</b> · {eventText(m, t)} · <span title={dateTime(m.created_at, lang)}>{ago(m.created_at, t, lang)}</span>
                </li>
              ) : (
                <li key={m.comment_id} className="comment">
                  <p className="small muted" style={{ margin: 0 }}><b>{m.author_name || m.author_email}</b> · <span title={dateTime(m.created_at, lang)}>{ago(m.created_at, t, lang)}</span></p>
                  <p className="pre">{m.body}</p>
                  <FileList items={m.attachments} />
                </li>
              ))}
            </ol>
            <div className="stack no-print">
              <textarea rows={3} style={{ width: '100%' }} value={body} onChange={(e) => setBody(e.target.value)}
                aria-label={t('tickets.addComment')} placeholder={t('tickets.commentPlaceholder')} />
              <FilePicker value={files} onChange={setFiles} onBusy={setUploading} />
              <div className="row">
                <button className="primary right" disabled={!body.trim() || uploading || action.busy} onClick={() => void comment()}>{t('tickets.comment')}</button>
              </div>
            </div>
          </div>
        </div>

        <aside>
          <div className="card stack">
            <label className="field">{t('tickets.status')}
              <select value={x.status} disabled={action.busy} onChange={(e) => void patch({ status: e.target.value as TicketStatus })}>
                {TICKET_STATUSES.map((s) => <option key={s} value={s}>{t(`tickets.status_${s}`)}</option>)}
              </select>
            </label>
            <label className="field">{t('tickets.priority')}
              <select value={x.priority} disabled={action.busy} onChange={(e) => void patch({ priority: e.target.value as TicketPriority })}>
                {TICKET_PRIORITIES.map((p) => <option key={p} value={p}>{t(`tickets.prio_${p}`)}</option>)}
              </select>
            </label>
            <label className="field">{t('tickets.type')}
              <select value={x.type} disabled={action.busy} onChange={(e) => void patch({ type: e.target.value as TicketType })}>
                {TICKET_TYPES.map((p) => <option key={p} value={p}>{t(`tickets.type_${p}`)}</option>)}
              </select>
            </label>
            <label className="field">{t('tickets.area')}
              <select value={x.area} disabled={action.busy} onChange={(e) => void patch({ area: e.target.value })}>
                {(TICKET_AREAS as readonly string[]).includes(x.area) ? null : <option value={x.area}>{x.area}</option>}
                {TICKET_AREAS.map((a) => <option key={a} value={a}>{t(`tickets.area_${a}`)}</option>)}
              </select>
            </label>
          </div>

          <div className="card small">
            <h2>{t('tickets.technical')}</h2>
            {c.userAgent ? (
              <dl className="spec-meta">
                {([
                  [t('tickets.browser'), describeBrowser(c.userAgent)],
                  [t('tickets.window'), `${c.viewport?.width}×${c.viewport?.height}`],
                  [t('tickets.screen'), `${c.screen?.width}×${c.screen?.height} @${c.screen?.pixelRatio}x`],
                  [t('tickets.language'), `${c.appLanguage} (${c.language})`],
                  [t('tickets.timezone'), c.timezone],
                  [t('tickets.signedInAs'), c.signedInAs],
                  [t('tickets.online'), c.online ? t('common.yes') : t('common.no')],
                ] as [string, string | undefined][]).map(([k, v]) => <Fragment key={k}><dt>{k}</dt><dd className="break">{v || '—'}</dd></Fragment>)}
              </dl>
            ) : <p className="muted">{t('tickets.noContext')}</p>}
            {(['recentPages', 'consoleErrors'] as const).map((k) => {
              const items = (c[k] ?? []) as { at: string; path?: string; message?: string }[];
              if (!items.length) return null;
              return (
                <details key={k} open={k === 'consoleErrors'}>
                  <summary>{t(k === 'recentPages' ? 'tickets.recentPages' : 'tickets.errors', { count: items.length })}</summary>
                  <ul className="mono">
                    {items.map((it, i) => <li key={i}><span className="muted">{new Date(it.at).toLocaleTimeString(lang)} </span>{it.path ?? it.message}</li>)}
                  </ul>
                </details>
              );
            })}
          </div>
        </aside>
      </div>
    </>
  );
}
