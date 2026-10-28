import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { dateTime, supabase } from '../lib/supabase';

export type Photo = { photo_id: string; storage_path: string; captured_at: string | null; photo_kind: string };

// Signed links are private and short-lived; one hour covers a review session.
const LINK_SECONDS = 3600;

/**
 * Thumbnails for a record's photos. A photo row can sync before its file finishes uploading
 * from the truck, so a missing file shows as "not uploaded yet" rather than a broken image.
 */
export default function PhotoGallery({ photos, label }: { photos: Photo[]; label: string }) {
  const { t, i18n } = useTranslation();
  const [urls, setUrls] = useState<Record<string, string | null>>({});
  const [open, setOpen] = useState<Photo | null>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  const paths = photos.map((p) => p.storage_path).join('|');

  useEffect(() => {
    let cancelled = false;
    if (!photos.length) return;
    supabase.storage.from('photos').createSignedUrls(photos.map((p) => p.storage_path), LINK_SECONDS)
      .then(({ data }) => {
        if (cancelled) return;
        const next: Record<string, string | null> = {};
        for (const p of photos) {
          const hit = data?.find((d) => d.path === p.storage_path);
          next[p.storage_path] = hit && !hit.error && hit.signedUrl ? hit.signedUrl : null;
        }
        setUrls(next);
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paths]);

  useEffect(() => {
    const d = dialog.current;
    if (!d) return;
    if (open && !d.open) d.showModal();
    if (!open && d.open) d.close();
  }, [open]);

  if (!photos.length) return null;

  return (
    <>
      <div className="thumbs">
        {photos.map((p, i) => {
          const url = urls[p.storage_path];
          const loading = !(p.storage_path in urls);
          const alt = `${label} ${i + 1}`;
          if (url) {
            return (
              <button key={p.photo_id} type="button" className="thumb" onClick={() => setOpen(p)} title={alt}>
                <img src={url} alt={alt} loading="lazy" />
              </button>
            );
          }
          return (
            <div key={p.photo_id} className="thumb pending" title={alt}>
              <span>{loading ? t('common.loading') : t('shift.photoNotUploaded')}</span>
            </div>
          );
        })}
      </div>
      <dialog ref={dialog} className="lightbox" onClose={() => setOpen(null)} onCancel={() => setOpen(null)}>
        {open && urls[open.storage_path] && (
          <figure>
            <img src={urls[open.storage_path]!} alt={label} />
            <figcaption>
              <span>{label} · {t('shift.photoTaken')} {dateTime(open.captured_at, i18n.language)}</span>
              <span className="row">
                <a href={urls[open.storage_path]!} target="_blank" rel="noopener noreferrer">{t('shift.openFull')}</a>
                <button type="button" onClick={() => setOpen(null)}>{t('common.close')}</button>
              </span>
            </figcaption>
          </figure>
        )}
      </dialog>
    </>
  );
}
