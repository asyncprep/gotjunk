import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { signedUrls, uploadAttachment, type Attachment } from '../lib/tickets';

const isImage = (a: Attachment) => a.type.startsWith('image/') || /\.(png|jpe?g|webp|gif|avif)$/i.test(a.name);

/** Thumbnails of attached files; they open full size in a new tab. */
export function FileList({ items, onRemove }: { items: Attachment[]; onRemove?: (i: number) => void }) {
  const { t } = useTranslation();
  const [urls, setUrls] = useState<Record<string, string>>({});
  const key = items.map((a) => a.path).join('|');
  useEffect(() => {
    let live = true;
    signedUrls(items.map((a) => a.path)).then((u) => { if (live) setUrls(u); }).catch(() => undefined);
    return () => { live = false; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);
  if (!items.length) return null;
  return (
    <ul className="ticket-files">
      {items.map((a, i) => (
        <li key={a.path}>
          <a href={urls[a.path]} target="_blank" rel="noreferrer" title={a.name}>
            {isImage(a) && urls[a.path] ? <img src={urls[a.path]} alt={a.name} /> : <span className="file-name">{a.name}</span>}
          </a>
          {onRemove && (
            <button type="button" className="remove" aria-label={t('tickets.removeFile')} onClick={() => onRemove(i)}>×</button>
          )}
        </li>
      ))}
    </ul>
  );
}

/** Grabs one frame of a tab, window or screen the person picks (desktop browsers). */
async function captureScreen(): Promise<File | null> {
  const stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: false, preferCurrentTab: true } as DisplayMediaStreamOptions);
  try {
    const video = document.createElement('video');
    video.srcObject = stream;
    video.muted = true;
    await video.play();
    await new Promise((r) => setTimeout(r, 350)); // let the frame settle once the picker closes
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d')!.drawImage(video, 0, 0);
    const blob = await new Promise<Blob | null>((r) => canvas.toBlob(r, 'image/png'));
    return blob ? new File([blob], `capture-${new Date().toISOString().replace(/[:.]/g, '-')}.png`, { type: 'image/png' }) : null;
  } finally {
    stream.getTracks().forEach((track) => track.stop());
  }
}
const canCaptureScreen = () =>
  typeof navigator !== 'undefined' && Boolean(navigator.mediaDevices?.getDisplayMedia) && !/Mobi|Android|iPhone|iPad/i.test(navigator.userAgent);

/**
 * Drop zone, paste, file picker and screenshot. `onHide` hides the surrounding form while a
 * screenshot is taken, so it isn't in the picture.
 */
export function FilePicker({ value, onChange, onHide, onBusy, pasteTarget }: {
  value: Attachment[]; onChange: (v: Attachment[]) => void; onHide?: (hidden: boolean) => void;
  onBusy?: (uploading: boolean) => void; pasteTarget?: HTMLElement | null;
}) {
  const { t } = useTranslation();
  const input = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(0);
  const [error, setError] = useState('');
  const [over, setOver] = useState(false);
  const latest = useRef(value);
  latest.current = value;
  useEffect(() => { onBusy?.(busy > 0); }, [busy, onBusy]);

  const add = async (files: File[]) => {
    setError('');
    for (const f of files) {
      setBusy((b) => b + 1);
      try {
        latest.current = [...latest.current, await uploadAttachment(f)];
        onChange(latest.current);
      } catch (e) {
        setError((e as Error).message === 'file_too_big' ? t('tickets.fileTooBig', { name: f.name }) : t('tickets.uploadFailed'));
      } finally {
        setBusy((b) => b - 1);
      }
    }
  };

  // Ctrl+V / Cmd+V of an image anywhere in the form attaches it.
  useEffect(() => {
    const el = pasteTarget ?? document;
    const onPaste = (e: Event) => {
      const files = [...((e as ClipboardEvent).clipboardData?.files ?? [])];
      if (files.length) { e.preventDefault(); e.stopPropagation(); void add(files); }
    };
    el.addEventListener('paste', onPaste);
    return () => el.removeEventListener('paste', onPaste);
  });

  const screenshot = async () => {
    setError('');
    onHide?.(true);
    try {
      const f = await captureScreen();
      if (f) await add([f]);
    } catch (e) {
      if ((e as Error).name !== 'NotAllowedError') setError(t('tickets.captureFailed'));
    } finally {
      onHide?.(false);
    }
  };

  return (
    <div className="stack">
      <div className={`drop ${over ? 'over' : ''}`}
        onDragOver={(e) => { e.preventDefault(); setOver(true); }}
        onDragLeave={() => setOver(false)}
        onDrop={(e) => { e.preventDefault(); setOver(false); void add([...e.dataTransfer.files]); }}>
        <p className="muted small">{t('tickets.dropHint')}</p>
        <div className="row" style={{ justifyContent: 'center' }}>
          <button type="button" onClick={() => input.current?.click()}>{t('tickets.chooseFiles')}</button>
          {canCaptureScreen() && <button type="button" onClick={() => void screenshot()}>{t('tickets.takeScreenshot')}</button>}
        </div>
        <input ref={input} type="file" multiple hidden accept="image/*,video/mp4,video/quicktime,video/webm,application/pdf"
          onChange={(e) => { void add([...(e.target.files ?? [])]); e.target.value = ''; }} />
      </div>
      {busy > 0 && <p className="muted small">{t('tickets.uploading')}</p>}
      {error && <p className="small" style={{ color: 'var(--red)' }}>{error}</p>}
      <FileList items={value} onRemove={(i) => onChange(value.filter((_, j) => j !== i))} />
    </div>
  );
}
