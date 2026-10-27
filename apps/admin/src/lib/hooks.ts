import { useCallback, useEffect, useState } from 'react';
import { explainError } from '../i18n';

// Loads data, exposes reload(), and turns failures into a readable message.
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const reload = useCallback(async () => {
    setLoading(true);
    try {
      setData(await load());
      setError(null);
    } catch (e) {
      setError(explainError((e as Error).message));
    } finally {
      setLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    reload();
  }, [reload]);

  return { data, error, loading, reload };
}

// Runs an action, reports its outcome, then refreshes.
export function useAction(onDone: () => unknown) {
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ ok: boolean; text: string } | null>(null);

  const run = useCallback(async (fn: () => Promise<unknown>, okText?: string) => {
    setBusy(true);
    try {
      await fn();
      setNotice(okText ? { ok: true, text: okText } : null);
      await onDone();
    } catch (e) {
      setNotice({ ok: false, text: explainError((e as Error).message) });
    } finally {
      setBusy(false);
    }
  }, [onDone]);

  return { busy, notice, setNotice, run };
}
