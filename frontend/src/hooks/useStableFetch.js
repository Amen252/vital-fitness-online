import { useCallback, useEffect, useRef, useState } from "react";
import { getErrorMessage, withHardTimeout } from "../api/client";

/**
 * Fetch helper that ignores stale responses when deps change mid-flight.
 * Soft-refreshes when data already exists (no full-page loading wipe).
 * Always clears loading (hard timeout) so screens never stick on Loading…
 * @param {() => Promise<any>} fetcher
 * @param {unknown[]} deps
 */
export default function useStableFetch(fetcher, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const requestId = useRef(0);
  const hasDataRef = useRef(false);
  const fetcherRef = useRef(fetcher);
  fetcherRef.current = fetcher;

  const reload = useCallback(async () => {
    const id = ++requestId.current;
    // Full-screen loading only on the first successful-data load.
    if (!hasDataRef.current) setLoading(true);
    setError("");
    try {
      const result = await withHardTimeout(fetcherRef.current());
      if (id !== requestId.current) return;
      setData(result ?? null);
      hasDataRef.current = true;
    } catch (err) {
      if (id !== requestId.current) return;
      setError(getErrorMessage(err));
      if (!hasDataRef.current) setData(null);
    } finally {
      // Always clear loading for this generation so abandoned/timed-out
      // requests cannot leave the UI stuck on a spinner.
      if (id === requestId.current) setLoading(false);
    }
  }, []);

  useEffect(() => {
    reload();
    return () => {
      requestId.current += 1;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- deps come from the caller
  }, deps);

  return { data, loading, error, reload };
}
