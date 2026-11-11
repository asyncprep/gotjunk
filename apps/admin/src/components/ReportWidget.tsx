import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { explainError } from '../i18n';
import { useAuth } from '../lib/auth';
import { collectContext, describeBrowser, recordPage } from '../lib/diagnostics';
import { must, supabase } from '../lib/supabase';
import {
  FREQUENCIES, TICKET_AREAS, areaFromPath, ticketsChanged,
  type Attachment, type Frequency, type Ticket, type TicketPriority, type TicketType,
} from '../lib/tickets';
import { FilePicker } from './TicketFiles';

/**
 * Team feedback, everywhere in the admin: a "Report" button on every page opens a short form for a
 * bug, a suggestion or a question for the client. The page, the browser and recent errors are
 * attached automatically, and shown before sending.
 */
export default function ReportWidget() {
  const location = useLocation();
  const [open, setOpen] = useState<TicketType | null>(null);

  // Remember the last pages visited, for "how did you get there".
  useEffect(() => { recordPage(location.pathname + location.search); }, [location.pathname, location.search]);

  useEffect(() => {
    const onOpen = (e: Event) => setOpen(((e as CustomEvent).detail as TicketType) ?? 'bug');
    window.addEventListener('tto:report', onOpen);
    return () => window.removeEventListener('tto:report', onOpen);
  }, []);

  return (
    <>
      {!open && <ReportButton onClick={() => setOpen('bug')} />}
      {open && <ReportForm initialType={open} onClose={() => setOpen(null)} />}
    </>
  );
}

function ReportButton({ onClick }: { onClick: () => void }) {
  const { t } = useTranslation();
  return (
    <button type="button" className="report-button no-print" onClick={onClick} aria-label={t('tickets.reportAria')}>
      {t('tickets.report')}
    </button>
  );
}

const DRAFT_KEY = 'tto.ticket.draft';
type Draft = {
  type: TicketType; title: string; area: string; priority: TicketPriority; page_url: string;
  description: string; steps: string; expected: string; frequency: Frequency | null; reason: string;
  attachments: Attachment[];
};

const blank = (type: TicketType, path: string): Draft => ({
  type, title: '', area: areaFromPath(path), priority: 'normal', page_url: window.location.href,
  description: '', steps: '', expected: '', frequency: null, reason: '', attachments: [],
});

function Choice<T extends string>({ options, value, onChange, name }: {
  options: [T, string, string?][]; value: T | null; onChange: (v: T) => void; name: string;
}) {
  return (
    <div role="radiogroup" aria-label={name} className="choice" style={{ gridTemplateColumns: `repeat(${Math.min(options.length, 4)}, minmax(0, 1fr))` }}>
      {options.map(([v, label, hint]) => (
        <button key={v} type="button" role="radio" aria-checked={value === v} className={value === v ? 'on' : ''} onClick={() => onChange(v)}>
          <b>{label}</b>
          {hint && <span>{hint}</span>}
        </button>
      ))}
    </div>
  );
}

function Q({ label, hint, required, children, htmlFor }: { label: string; hint?: string; required?: boolean; children: ReactNode; htmlFor?: string }) {
  const { t } = useTranslation();
  return (
    <div className="q">
      <label htmlFor={htmlFor}>
        {label} {required ? <span className="req">*</span> : <span className="muted small">({t('tickets.optional')})</span>}
      </label>
      {hint && <p className="muted small">{hint}</p>}
      {children}
    </div>
  );
}

function ReportForm({ initialType, onClose }: { initialType: TicketType; onClose: () => void }) {
  const { t } = useTranslation();
  const { session } = useAuth();
  const location = useLocation();
  const email = session?.user.email ?? '';
  const [panel, setPanel] = useState<HTMLDivElement | null>(null);
  const [draft, setDraft] = useState<Draft>(() => {
    try {
      const saved = JSON.parse(localStorage.getItem(DRAFT_KEY) ?? 'null') as Draft | null;
      if (saved?.title || saved?.description) return { ...saved, type: initialType };
    } catch { /* start fresh */ }
    return blank(initialType, location.pathname);
  });
  const [attachContext, setAttachContext] = useState(true);
  const [showContext, setShowContext] = useState(false);
  const [hidden, setHidden] = useState(false);
  const [sending, setSending] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [sent, setSent] = useState<Pick<Ticket, 'number' | 'title'> | null>(null);
  const context = useMemo(() => collectContext(email), [email]);

  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setDraft((d) => ({ ...d, [k]: v }));
  const bug = draft.type === 'bug';
  const question = draft.type === 'question';

  // Keep an unsent draft if the form is closed by mistake.
  useEffect(() => {
    try { localStorage.setItem(DRAFT_KEY, JSON.stringify(draft)); } catch { /* not critical */ }
  }, [draft]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  const send = async () => {
    const errs: Record<string, string> = {};
    if (draft.title.trim().length < 3) errs.title = t('tickets.needTitle');
    if (!draft.description.trim()) errs.description = t(bug ? 'tickets.needWhatWrong' : question ? 'tickets.needQuestion' : 'tickets.needChange');
    setErrors(errs);
    if (Object.keys(errs).length) return;
    setSending(true);
    try {
      const row = await must(supabase.from('ticket').insert({
        ...draft,
        title: draft.title.trim(),
        priority: !bug && draft.priority === 'blocker' ? 'high' : draft.priority,
        steps: bug ? draft.steps : '',
        expected: bug ? draft.expected : '',
        frequency: bug ? draft.frequency : null,
        reason: bug ? '' : draft.reason,
        context: attachContext ? context : { url: window.location.href },
      }).select('number, title').single());
      try { localStorage.removeItem(DRAFT_KEY); } catch { /* fine */ }
      ticketsChanged();
      setSent(row);
    } catch (e) {
      setErrors({ form: explainError((e as Error).message) });
    } finally {
      setSending(false);
    }
  };

  const reset = (type: TicketType) => {
    setSent(null);
    setErrors({});
    setDraft(blank(type, location.pathname));
  };

  const severity: [TicketPriority, string, string][] = (['blocker', 'high', 'normal', 'low'] as const)
    .map((p) => [p, t(`tickets.sev_${p}`), t(`tickets.sevHint_${p}`)]);
  const importance: [TicketPriority, string, string][] = (['high', 'normal', 'low'] as const)
    .map((p) => [p, t(`tickets.imp_${p}`), t(`tickets.impHint_${p}`)]);
  const n = (count: number, key: string) => t(key, { count });

  return (
    <div className={`report-overlay ${hidden ? 'hidden' : ''}`} onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div ref={setPanel} role="dialog" aria-modal="true" aria-label={t('tickets.formTitle')} className="report-panel">
        <header>
          <div>
            <p className="muted small">{t('tickets.formTitle')}</p>
            <h2>{sent ? t('tickets.thanks') : t(`tickets.heading_${draft.type}`)}</h2>
          </div>
          <button type="button" className="ghost" onClick={onClose} aria-label={t('common.close')}>×</button>
        </header>

        {sent ? (
          <div className="report-sent">
            <p><b>{t('tickets.sentNumber', { number: sent.number })}</b></p>
            <p className="muted">{t('tickets.sentText', { title: sent.title })}</p>
            <div className="row" style={{ justifyContent: 'center' }}>
              <Link className="button primary" to={`/tickets/${sent.number}`} onClick={onClose}>{t('tickets.openTicket')}</Link>
              <button type="button" onClick={() => reset('bug')}>{t('tickets.reportAnother')}</button>
            </div>
          </div>
        ) : (
          <>
            <div className="report-body">
              <div className="choice types" role="radiogroup" aria-label={t('tickets.type')}>
                {(['bug', 'suggestion', 'question'] as const).map((v) => (
                  <button key={v} type="button" role="radio" aria-checked={draft.type === v} className={draft.type === v ? 'on' : ''} onClick={() => set('type', v)}>
                    <b>{t(`tickets.pick_${v}`)}</b>
                    <span>{t(`tickets.pickHint_${v}`)}</span>
                  </button>
                ))}
              </div>

              <Q label={t('tickets.shortTitle')} required htmlFor="t-title" hint={t(`tickets.titleHint_${draft.type}`)}>
                <input id="t-title" maxLength={140} value={draft.title} onChange={(e) => set('title', e.target.value)} />
                {errors.title && <p className="field-error">{errors.title}</p>}
              </Q>

              <div className="report-pair">
                <Q label={t('tickets.page')} htmlFor="t-url" hint={t('tickets.pageHint')}>
                  <input id="t-url" value={draft.page_url} onChange={(e) => set('page_url', e.target.value)} />
                </Q>
                <Q label={t('tickets.area')} htmlFor="t-area">
                  <select id="t-area" value={draft.area} onChange={(e) => set('area', e.target.value)}>
                    {TICKET_AREAS.map((a) => <option key={a} value={a}>{t(`tickets.area_${a}`)}</option>)}
                  </select>
                </Q>
              </div>

              <Q label={t(`tickets.describe_${draft.type}`)} required htmlFor="t-desc" hint={t(`tickets.describeHint_${draft.type}`)}>
                <textarea id="t-desc" rows={4} value={draft.description} onChange={(e) => set('description', e.target.value)} />
                {errors.description && <p className="field-error">{errors.description}</p>}
              </Q>

              {bug ? (
                <>
                  <Q label={t('tickets.steps')} htmlFor="t-steps" hint={t('tickets.stepsHint')}>
                    <textarea id="t-steps" rows={4} className="mono" value={draft.steps} onChange={(e) => set('steps', e.target.value)}
                      placeholder={t('tickets.stepsPlaceholder')} />
                  </Q>
                  <Q label={t('tickets.expected')} htmlFor="t-exp">
                    <textarea id="t-exp" rows={2} value={draft.expected} onChange={(e) => set('expected', e.target.value)} />
                  </Q>
                  <Q label={t('tickets.frequency')}>
                    <Choice name={t('tickets.frequency')} options={FREQUENCIES.map((f) => [f, t(`tickets.freq_${f}`)] as [Frequency, string])}
                      value={draft.frequency} onChange={(v) => set('frequency', v)} />
                  </Q>
                  <Q label={t('tickets.howBad')} required>
                    <Choice name={t('tickets.howBad')} options={severity} value={draft.priority} onChange={(v) => set('priority', v)} />
                  </Q>
                </>
              ) : (
                <>
                  <Q label={t(question ? 'tickets.whyAsk' : 'tickets.why')} htmlFor="t-why" hint={t(question ? 'tickets.whyAskHint' : 'tickets.whyHint')}>
                    <textarea id="t-why" rows={2} value={draft.reason} onChange={(e) => set('reason', e.target.value)} />
                  </Q>
                  <Q label={t('tickets.howImportant')} required>
                    <Choice name={t('tickets.howImportant')} options={importance}
                      value={draft.priority === 'blocker' ? 'high' : draft.priority} onChange={(v) => set('priority', v)} />
                  </Q>
                </>
              )}

              <Q label={t('tickets.files')} hint={t(bug ? 'tickets.filesHintBug' : 'tickets.filesHint')}>
                <FilePicker value={draft.attachments} onChange={(v) => set('attachments', v)} onHide={setHidden} onBusy={setUploading} pasteTarget={panel} />
              </Q>

              <div className="context-box">
                <label className="row" style={{ alignItems: 'flex-start', flexWrap: 'nowrap' }}>
                  <input type="checkbox" checked={attachContext} onChange={(e) => setAttachContext(e.target.checked)} />
                  <span>
                    <b>{t('tickets.attachContext')}</b>
                    <span className="muted small" style={{ display: 'block' }}>
                      {describeBrowser(context.userAgent)} · {context.viewport?.width}×{context.viewport?.height} · {context.appLanguage}
                      {' · '}{n(context.recentPages?.length ?? 0, 'tickets.nPages')} · {n(context.consoleErrors?.length ?? 0, 'tickets.nErrors')}
                    </span>
                  </span>
                </label>
                <button type="button" className="link small" onClick={() => setShowContext((s) => !s)}>
                  {t(showContext ? 'tickets.hideContext' : 'tickets.seeContext')}
                </button>
                {showContext && <pre>{JSON.stringify(context, null, 2)}</pre>}
              </div>
            </div>

            <footer>
              <p className="small">{errors.form ? <span style={{ color: 'var(--red)' }}>{errors.form}</span> : <span className="muted">{t('tickets.sentAs', { email })}</span>}</p>
              <div className="row">
                <button type="button" className="ghost" onClick={onClose}>{t('common.cancel')}</button>
                <button type="button" className="primary" onClick={() => void send()} disabled={sending || uploading}>
                  {sending ? t('tickets.sending') : uploading ? t('tickets.uploading') : t('tickets.send')}
                </button>
              </div>
            </footer>
          </>
        )}
      </div>
    </div>
  );
}
