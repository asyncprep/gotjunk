import { useTranslation } from 'react-i18next';
import { dateTime, money } from '../lib/supabase';
import PhotoGallery, { type Photo } from './PhotoGallery';

export type CashPatch = { counted?: string; envelope?: string; resolution?: string };

// Expected vs counted cash, the crew's photo of it, and the dispatcher's count.
export default function CashPanel({ expected, cash, photos, busy, lang, onChange, onSave }: {
  expected: number; cash: any; photos: Photo[]; busy: boolean; lang: string;
  onChange: (patch: CashPatch) => void; onSave: () => void;
}) {
  const { t } = useTranslation();
  if (!cash && expected <= 0) return <p className="muted">{t('shift.noCash')}</p>;
  // No cash record from the crew (phone lost…): dispatch can still record the count.
  const missing = !cash;
  cash = cash ?? { counted_cash: null };
  const counted = cash.counted_cash === null ? null : Number(cash.counted_cash);
  const variance = counted === null ? null : Math.round((counted - expected) * 100) / 100;
  const varianceLabel = variance === null ? t('shift.toCount')
    : variance === 0 ? t('shift.balanced') : variance > 0 ? t('shift.over') : t('shift.short');

  return (
    <div className="stack">
      <div className="cash-tiles">
        <div className="tile"><div className="v">{money(expected, lang)}</div><div className="k">{t('shift.expectedCash')}</div></div>
        <div className="tile"><div className="v">{counted === null ? '—' : money(counted, lang)}</div><div className="k">{t('shift.counted')}</div></div>
        <div className={`tile ${variance === null ? '' : variance === 0 ? 'good' : 'bad'}`}>
          <div className="v">{variance === null ? '—' : money(variance, lang)}</div>
          <div className="k">{t('shift.variance')} · {varianceLabel}</div>
        </div>
      </div>
      {missing && <p className="problem error">✕ {t('shift.cashNotSubmitted')}</p>}
      {photos.length
        ? <PhotoGallery photos={photos} label={t('shift.cashPhoto')} />
        : <p className="problem error small">✕ {t('problem.cash_photo_missing')}</p>}
      {cash.verified_at && (
        <p className="muted small">
          {t('shift.verifiedAt')} {dateTime(cash.verified_at, lang)}{cash.receiver?.email ? ` · ${t('shift.receivedBy')} ${cash.receiver.email}` : ''}
          {cash.envelope_id ? ` · ${t('shift.envelope')} ${cash.envelope_id}` : ''}
        </p>
      )}
      <div className="cash-form">
        <label>{t('shift.counted')}
          <input inputMode="decimal" defaultValue={cash.counted_cash ?? ''} onChange={(e) => onChange({ counted: e.target.value })} />
        </label>
        <label>{t('shift.envelope')}
          <input defaultValue={cash.envelope_id ?? ''} onChange={(e) => onChange({ envelope: e.target.value })} />
        </label>
        <label className="wide">{t('shift.resolution')}
          <input defaultValue={cash.mismatch_resolution ?? ''} onChange={(e) => onChange({ resolution: e.target.value })} />
        </label>
      </div>
      <div><button className="go" disabled={busy} onClick={onSave}>{t('shift.recordCount')}</button></div>
    </div>
  );
}
