import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';

type Props = {
  open: boolean;
  title: string;
  message?: string;
  /** 'text' asks for a required reason; 'date' asks for a date; 'confirm' only confirms. */
  kind: 'text' | 'date' | 'confirm';
  initial?: string;
  confirmLabel: string;
  danger?: boolean;
  onConfirm: (value: string) => void;
  onClose: () => void;
};

// Accessible modal (native <dialog>) used instead of window.prompt/confirm.
export default function AskDialog({ open, title, message, kind, initial = '', confirmLabel, danger, onConfirm, onClose }: Props) {
  const { t } = useTranslation();
  const ref = useRef<HTMLDialogElement>(null);
  const [value, setValue] = useState(initial);

  useEffect(() => {
    const d = ref.current;
    if (!d) return;
    if (open && !d.open) {
      setValue(initial);
      d.showModal();
    }
    if (!open && d.open) d.close();
  }, [open, initial]);

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (kind !== 'confirm' && !value.trim()) return;
    onConfirm(value.trim());
  };

  return (
    <dialog ref={ref} onClose={onClose} onCancel={onClose}>
      <form onSubmit={submit}>
        <h2>{title}</h2>
        {message && <p className="muted">{message}</p>}
        {kind === 'text' && (
          <textarea rows={3} required autoFocus value={value} onChange={(e) => setValue(e.target.value)}
            placeholder={t('shift.reasonPrompt')} />
        )}
        {kind === 'date' && <input type="date" required autoFocus value={value} onChange={(e) => setValue(e.target.value)} />}
        <div className="actions">
          <button type="button" onClick={onClose}>{t('common.cancel')}</button>
          <button className={danger ? 'primary' : 'go'} disabled={kind !== 'confirm' && !value.trim()}>{confirmLabel}</button>
        </div>
      </form>
    </dialog>
  );
}
