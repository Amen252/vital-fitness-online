import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
} from "react";
import { CheckCircle2, Info, TriangleAlert, X, XCircle } from "lucide-react";

const ToastContext = createContext(null);

const ICONS = {
  success: CheckCircle2,
  error: XCircle,
  warning: TriangleAlert,
  info: Info,
};

const TONES = {
  success:
    "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-900/50 dark:bg-emerald-950/80 dark:text-emerald-200",
  error:
    "border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-900/50 dark:bg-rose-950/80 dark:text-rose-200",
  warning:
    "border-amber-200 bg-amber-50 text-amber-900 dark:border-amber-900/50 dark:bg-amber-950/80 dark:text-amber-200",
  info: "border-[color-mix(in_srgb,var(--vf-accent)_28%,transparent)] bg-[color-mix(in_srgb,var(--vf-accent)_10%,white)] text-[var(--vf-primary-deep)] dark:border-[color-mix(in_srgb,var(--vf-accent)_35%,transparent)] dark:bg-[color-mix(in_srgb,var(--vf-accent)_18%,black)] dark:text-[#7dd3fc]",
};

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const dismiss = useCallback((id) => {
    setToasts((list) => list.filter((t) => t.id !== id));
  }, []);

  const push = useCallback(
    (message, type = "info") => {
      const id = `${Date.now()}-${Math.random()}`;
      setToasts((list) => [...list, { id, message, type }]);
      window.setTimeout(() => dismiss(id), 3400);
    },
    [dismiss],
  );

  const value = useMemo(
    () => ({
      toast: {
        success: (msg) => push(msg, "success"),
        error: (msg) => push(msg, "error"),
        warning: (msg) => push(msg, "warning"),
        info: (msg) => push(msg, "info"),
      },
    }),
    [push],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div className="pointer-events-none fixed right-4 top-4 z-[80] flex w-[min(100%-2rem,380px)] flex-col gap-2">
        {toasts.map((t) => {
          const Icon = ICONS[t.type] || Info;
          return (
            <div
              key={t.id}
              className={`pointer-events-auto vf-animate-in flex items-start gap-3 rounded-[12px] border px-3 py-3 shadow-lg ${TONES[t.type]}`}
            >
              <Icon className="mt-0.5 h-5 w-5 shrink-0" />
              <p className="flex-1 text-sm font-medium">{t.message}</p>
              <button
                type="button"
                onClick={() => dismiss(t.id)}
                className="rounded-lg p-1 opacity-70 hover:opacity-100"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast() {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used within ToastProvider");
  return ctx.toast;
}
