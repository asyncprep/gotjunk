import { useState } from 'react';
import { useTranslation } from 'react-i18next';

export type DumpMaterial = { material_type_id: string; name: string };

/** Weight typed by dispatch, in kg: comma or dot, up to one decimal, more than 0. */
export function parseWeight(text: string): number | null {
  const cleaned = text.replace(/[\s  ]/g, '').replace(',', '.');
  if (!/^\d+(\.\d)?$/.test(cleaned)) return null;
  const kg = Number(cleaned);
  return kg > 0 ? kg : null;
}

/** Dispatch adds a weigh-in line to a dump visit (material + kg), as the crew does in the app. */
export default function DumpLineForm({ materials, busy, onAdd }: {
  materials: DumpMaterial[]; busy: boolean; onAdd: (materialTypeId: string, kg: number) => Promise<unknown> | void;
}) {
  const { t } = useTranslation();
  const [material, setMaterial] = useState('');
  const [weight, setWeight] = useState('');
  const [error, setError] = useState('');

  if (!materials.length) return <p className="muted small">{t('shift.noMaterialsAtSite')}</p>;
  const add = async () => {
    const kg = parseWeight(weight);
    if (!material) return setError(t('shift.pickMaterial'));
    if (kg === null) return setError(t('shift.invalidWeight'));
    setError('');
    // Keep what was typed if the server refused it.
    if ((await onAdd(material, kg)) === false) return;
    setMaterial('');
    setWeight('');
  };
  return (
    <div className="row" style={{ marginTop: 6 }}>
      <select value={material} onChange={(e) => setMaterial(e.target.value)} aria-label={t('shift.material')}>
        <option value="">{t('shift.material')}…</option>
        {materials.map((m) => <option key={m.material_type_id} value={m.material_type_id}>{m.name}</option>)}
      </select>
      <input value={weight} onChange={(e) => setWeight(e.target.value)} inputMode="decimal" style={{ width: 110 }}
        placeholder="kg" aria-label={t('shift.weight')} onKeyDown={(e) => { if (e.key === 'Enter') void add(); }} />
      <button disabled={busy} onClick={() => void add()}>{t('shift.addLine')}</button>
      {error && <span className="err-text small">{error}</span>}
    </div>
  );
}
