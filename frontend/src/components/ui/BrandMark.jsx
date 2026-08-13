import clsx from "clsx";
import { Dumbbell } from "lucide-react";

export function BrandMark({ size = "md", showText = true, light = false }) {
  const icon = {
    sm: "h-6 w-6",
    md: "h-7 w-7",
    lg: "h-8 w-8" };

  return (
    <div className="flex items-center gap-3">
      <Dumbbell
        className={clsx(
          "shrink-0",
          icon[size],
          light ? "text-[var(--vf-primary-light)]" : "text-[var(--vf-primary)]",
        )}
        strokeWidth={2}
      />
      {showText ? (
        <div className="min-w-0">
          <p
            className={clsx(
              "truncate text-sm font-bold tracking-tight",
              light ? "text-white" : "text-[var(--vf-text)]",
            )}
          >
            Vital Fitness
          </p>
          <p
            className={clsx(
              "truncate text-[11px] font-semibold uppercase tracking-[0.16em]",
              light
                ? "text-[var(--vf-primary-light)]"
                : "text-[var(--vf-primary)]",
            )}
          >
            Admin
          </p>
        </div>
      ) : null}
    </div>
  );
}

export function cn(...args) {
  return clsx(args);
}
