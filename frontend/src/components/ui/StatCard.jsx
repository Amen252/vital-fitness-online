import { cn } from "./BrandMark";

export function StatCard({ label, value, hint, icon: Icon, tone = "primary" }) {
  const tones = {
    primary: "from-[#2E3A6B] to-[#3D4F9F]",
    accent: "from-[#0284C7] to-[#0EA5E9]",
    success: "from-[#047857] to-[#059669]",
    warning: "from-[#B45309] to-[#D97706]",
    pink: "from-[#BE185D] to-[#DB2777]" };

  return (
    <div className="vf-card group relative overflow-hidden p-5 transition duration-200 hover:-translate-y-0.5 hover:shadow-md vf-animate-in">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--vf-muted)]">
            {label}
          </p>
          <p className="mt-2 text-3xl font-bold tracking-tight text-[var(--vf-text)]">
            {value ?? "—"}
          </p>
          {hint ? (
            <p className="mt-1 text-xs text-[var(--vf-muted)]">{hint}</p>
          ) : null}
        </div>
        {Icon ? (
          <div
            className={cn(
              "flex h-11 w-11 items-center justify-center rounded-[12px] bg-gradient-to-br text-white shadow-md",
              tones[tone],
            )}
          >
            <Icon className="h-5 w-5" />
          </div>
        ) : null}
      </div>
    </div>
  );
}
