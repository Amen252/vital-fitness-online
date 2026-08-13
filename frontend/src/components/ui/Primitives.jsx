import { cn } from "./BrandMark";

export function Card({ children, className, hover = false, ...props }) {
  return (
    <div
      {...props}
      className={cn(
        "vf-card transition-all duration-200",
        hover && "hover:-translate-y-0.5 hover:shadow-md",
        className,
      )}
    >
      {children}
    </div>
  );
}

export function Button({
  children,
  className,
  variant = "primary",
  size = "md",
  type = "button",
  ...props
}) {
  const variants = {
    primary:
      "bg-[var(--vf-primary)] text-white hover:bg-[var(--vf-primary-light)] shadow-sm shadow-[rgba(61,79,159,0.25)]",
    secondary:
      "bg-[var(--vf-surface-muted)] text-[var(--vf-text)] border border-[var(--vf-border)] hover:bg-[var(--vf-border)]/40",
    accent: "bg-[var(--vf-accent)] text-white hover:brightness-110",
    danger: "bg-[var(--vf-danger)] text-white hover:brightness-110",
    ghost:
      "bg-transparent text-[var(--vf-muted)] hover:bg-[var(--vf-surface-muted)] hover:text-[var(--vf-text)]" };
  const sizes = {
    sm: "px-3 py-1.5 text-xs",
    md: "px-4 py-2.5 text-sm",
    lg: "px-5 py-3 text-sm" };

  return (
    <button
      type={type}
      className={cn(
        "inline-flex items-center justify-center gap-2 rounded-[12px] font-semibold transition disabled:cursor-not-allowed disabled:opacity-55 vf-focus",
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
}

export function Badge({ children, tone = "slate", className }) {
  const tones = {
    slate: "bg-slate-100 text-slate-700 dark:bg-white/10 dark:text-white/80",
    primary:
      "bg-[color-mix(in_srgb,var(--vf-primary)_14%,white)] text-[var(--vf-primary)] dark:bg-[color-mix(in_srgb,var(--vf-primary)_28%,black)] dark:text-[#c7d0f5]",
    green:
      "bg-emerald-100 text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300",
    amber:
      "bg-amber-100 text-amber-800 dark:bg-amber-500/15 dark:text-amber-300",
    red: "bg-rose-100 text-rose-700 dark:bg-rose-500/15 dark:text-rose-300",
    blue: "bg-[color-mix(in_srgb,var(--vf-accent)_14%,white)] text-[var(--vf-accent)] dark:bg-[color-mix(in_srgb,var(--vf-accent)_22%,black)] dark:text-[#7dd3fc]" };
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-bold uppercase tracking-wide",
        tones[tone],
        className,
      )}
    >
      {children}
    </span>
  );
}

export function Skeleton({ className }) {
  return null;
}

export function PageHeader({ title, subtitle, action, breadcrumbs }) {
  return (
    <div className="mb-6 vf-animate-in">
      {breadcrumbs}
      <div className="mt-2 flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-[var(--vf-text)] md:text-[28px]">
            {title}
          </h1>
          {subtitle ? (
            <p className="mt-1 text-sm text-[var(--vf-muted)]">{subtitle}</p>
          ) : null}
        </div>
        {action}
      </div>
    </div>
  );
}

export function EmptyState({ icon: Icon, title, description, action }) {
  return (
    <div className="vf-card flex min-h-[240px] flex-col items-center justify-center px-6 py-14 text-center vf-animate-in">
      {Icon ? (
        <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl bg-[color-mix(in_srgb,var(--vf-primary)_12%,transparent)] text-[var(--vf-primary)]">
          <Icon className="h-7 w-7" />
        </div>
      ) : null}
      <h3 className="max-w-md text-lg font-bold text-[var(--vf-text)]">{title}</h3>
      {description ? (
        <p className="mt-2 max-w-md text-sm leading-relaxed text-[var(--vf-muted)]">
          {description}
        </p>
      ) : null}
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}

export function ErrorState({ message, onRetry }) {
  return (
    <div className="rounded-[16px] border border-rose-200 bg-rose-50 p-6 text-rose-700 dark:border-rose-900/40 dark:bg-rose-950/40 dark:text-rose-200 vf-animate-in">
      <p className="font-semibold">{message}</p>
      {onRetry ? (
        <Button variant="danger" size="sm" className="mt-3" onClick={onRetry}>
          Retry
        </Button>
      ) : null}
    </div>
  );
}

export function LoadingBlock({ rows = 4 }) {
  return null;
}

/** No loading UI — kept for API compatibility with existing imports. */
export function Spinner() {
  return null;
}
