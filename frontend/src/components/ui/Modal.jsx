import { useEffect } from "react";
import { X } from "lucide-react";
import { Button } from "./Primitives";

export function Modal({
  open,
  title,
  children,
  onClose,
  footer,
  wide = false,
}) {
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (e) => {
      if (e.key === "Escape") onClose?.();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center p-4 sm:items-center">
      <button
        type="button"
        className="absolute inset-0 bg-slate-950/50 backdrop-blur-[2px]"
        onClick={onClose}
        aria-label="Close modal"
      />
      <div
        className={`relative z-10 max-h-[90vh] w-full overflow-hidden rounded-[16px] border border-[var(--vf-border)] bg-[var(--vf-surface)] shadow-2xl vf-animate-in ${
          wide ? "max-w-3xl" : "max-w-lg"
        }`}
      >
        <div className="flex items-center justify-between border-b border-[var(--vf-border)] px-5 py-4">
          <h3 className="text-lg font-bold text-[var(--vf-text)]">{title}</h3>
          <Button
            variant="ghost"
            size="sm"
            onClick={onClose}
            aria-label="Close"
          >
            <X className="h-4 w-4" />
          </Button>
        </div>
        <div className="max-h-[calc(90vh-8rem)] overflow-y-auto px-5 py-4">
          {children}
        </div>
        {footer ? (
          <div className="border-t border-[var(--vf-border)] px-5 py-4">
            {footer}
          </div>
        ) : null}
      </div>
    </div>
  );
}
