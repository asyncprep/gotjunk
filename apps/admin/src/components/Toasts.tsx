import { useEffect, useState } from 'react';

type Toast = { id: number; ok: boolean; text: string };
type Listener = (t: Toast) => void;

const listeners = new Set<Listener>();
let nextId = 1;

/** Shows a short message in the corner. Errors stay longer than confirmations. */
export function toast(text: string, ok = true) {
  const t = { id: nextId++, ok, text };
  listeners.forEach((l) => l(t));
}

export default function Toasts() {
  const [items, setItems] = useState<Toast[]>([]);

  useEffect(() => {
    const add: Listener = (t) => {
      setItems((list) => [...list, t]);
      setTimeout(() => setItems((list) => list.filter((x) => x.id !== t.id)), t.ok ? 3000 : 7000);
    };
    listeners.add(add);
    return () => {
      listeners.delete(add);
    };
  }, []);

  return (
    <div className="toasts" role="status" aria-live="polite">
      {items.map((t) => (
        <div key={t.id} className={`toast ${t.ok ? 'ok' : 'err'}`}>{t.text}</div>
      ))}
    </div>
  );
}
