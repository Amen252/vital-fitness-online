import { Link } from "react-router-dom";
import { ChevronRight } from "lucide-react";

export function Breadcrumbs({ items = [] }) {
  return (
    <nav className="flex flex-wrap items-center gap-1 text-xs text-[var(--vf-muted)]">
      {items.map((item, index) => {
        const last = index === items.length - 1;
        return (
          <span
            key={`${item.label}-${index}`}
            className="inline-flex items-center gap-1"
          >
            {index > 0 ? (
              <ChevronRight className="h-3.5 w-3.5 opacity-60" />
            ) : null}
            {item.to && !last ? (
              <Link
                to={item.to}
                className="font-medium hover:text-[var(--vf-primary)]"
              >
                {item.label}
              </Link>
            ) : (
              <span className={last ? "font-semibold text-[var(--vf-text)]" : ""}>
                {item.label}
              </span>
            )}
          </span>
        );
      })}
    </nav>
  );
}
