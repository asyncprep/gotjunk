import { useCallback, useEffect, useState } from 'react';
import { explainError } from '../i18n';
import { toast } from '../components/Toasts';

// Loads data, exposes reload(), and turns failures into a readable message.
// `quiet` reloads keep the current data on screen (no loading flash), for background refresh.
export function useLoad<T>(load: () => Promise<T>, deps: unknown[]) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const reload = useCallback(async (quiet = false) => {
    if (!quiet) setLoading(true);
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

  return { data, error, loading, reload, setData };
}

// Runs an action, reports the outcome as a toast, then refreshes quietly.
export function useAction(onDone: (quiet?: boolean) => unknown) {
  const [busy, setBusy] = useState(false);

  const run = useCallback(async (fn: () => Promise<unknown>, okText?: string) => {
    setBusy(true);
    try {
      await fn();
      if (okText) toast(okText);
      await onDone(true);
      return true;
    } catch (e) {
      toast(explainError((e as Error).message), false);
      await onDone(true);
      return false;
    } finally {
      setBusy(false);
    }
  }, [onDone]);

  return { busy, run };
}
