import { useMemo, useState } from "react";
import { ChevronLeft, ChevronRight, Search } from "lucide-react";
import { EmptyState } from "./Primitives";
import { Button } from "./Primitives";

export function DataTable({
  columns,
  rows,
  rowKey = (row) => row._id || row.id,
  searchKeys = [],
  searchPlaceholder = "Search…",
  initialQuery = "",
  pageSize: initialPageSize = 25,
  pageSizeOptions = [10, 25, 50, 0],
  emptyTitle = "No records found",
  emptyDescription = "Try adjusting filters or check back later.",
  emptyIcon,
  filters,
  onRowClick,
}) {
  const [query, setQuery] = useState(initialQuery);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(initialPageSize);
  const [sort, setSort] = useState({ key: null, dir: "asc" });

  const filtered = useMemo(() => {
    let list = [...(rows || [])];
    if (query.trim() && searchKeys.length) {
      const q = query.trim().toLowerCase();
      list = list.filter((row) =>
        searchKeys.some((key) => {
          const value = resolve(row, key);
          if (Array.isArray(value)) {
            return value.some((item) =>
              String(item ?? "")
                .toLowerCase()
                .includes(q),
            );
          }
          return String(value ?? "")
            .toLowerCase()
            .includes(q);
        }),
      );
    }
    if (sort.key) {
      list.sort((a, b) => {
        const av = resolve(a, sort.key);
        const bv = resolve(b, sort.key);
        if (av == null && bv == null) return 0;
        if (av == null) return 1;
        if (bv == null) return -1;
        if (typeof av === "number" && typeof bv === "number") {
          return sort.dir === "asc" ? av - bv : bv - av;
        }
        return sort.dir === "asc"
          ? String(av).localeCompare(String(bv))
          : String(bv).localeCompare(String(av));
      });
    }
    return list;
  }, [rows, query, searchKeys, sort]);

  const totalPages =
    pageSize <= 0 ? 1 : Math.max(1, Math.ceil(filtered.length / pageSize));
  const currentPage = Math.min(page, totalPages);
  const pageRows =
    pageSize <= 0
      ? filtered
      : filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize);

  function toggleSort(key) {
    setSort((prev) => {
      if (prev.key !== key) return { key, dir: "asc" };
      if (prev.dir === "asc") return { key, dir: "desc" };
      return { key: null, dir: "asc" };
    });
  }

  return (
    <div className="vf-card overflow-hidden vf-animate-in">
      <div className="flex flex-wrap items-center gap-3 border-b border-[var(--vf-border)] p-4">
        <div className="relative min-w-[220px] flex-1">
          <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--vf-muted)]" />
          <input
            value={query}
            onChange={(e) => {
              setQuery(e.target.value);
              setPage(1);
            }}
            placeholder={searchPlaceholder}
            className="w-full rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] py-2.5 pl-10 pr-3 text-sm outline-none ring-[var(--vf-accent)] focus:ring-2"
          />
        </div>
        {filters}
        {pageSizeOptions?.length ? (
          <select
            value={pageSize}
            onChange={(e) => {
              setPageSize(Number(e.target.value));
              setPage(1);
            }}
            className="rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-2.5 text-sm"
            aria-label="Rows per page"
          >
            {pageSizeOptions.map((size) => (
              <option key={size} value={size}>
                {size <= 0 ? "Show all" : `${size} per page`}
              </option>
            ))}
          </select>
        ) : null}
      </div>

      {pageRows.length === 0 ? (
        <div className="p-4">
          <EmptyState
            icon={emptyIcon}
            title={emptyTitle}
            description={emptyDescription}
          />
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="min-w-full text-left text-sm">
            <thead className="bg-[var(--vf-surface-muted)] text-[var(--vf-muted)]">
              <tr>
                {columns.map((col) => (
                  <th
                    key={col.key}
                    className="px-4 py-3 text-xs font-bold uppercase tracking-wide"
                  >
                    {col.sortable ? (
                      <button
                        type="button"
                        onClick={() => toggleSort(col.sortKey || col.key)}
                        className="inline-flex items-center gap-1 hover:text-[var(--vf-primary)]"
                      >
                        {col.header}
                        {sort.key === (col.sortKey || col.key) ? (
                          <span>{sort.dir === "asc" ? "↑" : "↓"}</span>
                        ) : null}
                      </button>
                    ) : (
                      col.header
                    )}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {pageRows.map((row) => (
                <tr
                  key={rowKey(row)}
                  onClick={() => onRowClick?.(row)}
                  className={`border-t border-[var(--vf-border)] transition hover:bg-[color-mix(in_srgb,var(--vf-primary)_5%,transparent)] ${
                    onRowClick ? "cursor-pointer" : ""
                  }`}
                >
                  {columns.map((col) => (
                    <td key={col.key} className="px-4 py-3 align-middle">
                      {col.render ? col.render(row) : resolve(row, col.key)}
                    </td>
                  ))}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="flex items-center justify-between gap-3 border-t border-[var(--vf-border)] px-4 py-3 text-sm text-[var(--vf-muted)]">
        <p>
          {pageSize <= 0 ? (
            `Showing all ${filtered.length} record${filtered.length === 1 ? "" : "s"}`
          ) : (
            <>
              Showing{" "}
              {filtered.length === 0 ? 0 : (currentPage - 1) * pageSize + 1}–
              {Math.min(currentPage * pageSize, filtered.length)} of{" "}
              {filtered.length}
            </>
          )}
        </p>
        {pageSize > 0 ? (
          <div className="flex items-center gap-2">
            <Button
              variant="secondary"
              size="sm"
              disabled={currentPage <= 1}
              onClick={() => setPage((p) => p - 1)}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <span className="min-w-16 text-center text-[var(--vf-text)]">
              {currentPage} / {totalPages}
            </span>
            <Button
              variant="secondary"
              size="sm"
              disabled={currentPage >= totalPages}
              onClick={() => setPage((p) => p + 1)}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        ) : null}
      </div>
    </div>
  );
}

function resolve(obj, path) {
  if (!path) return undefined;
  return path
    .split(".")
    .reduce((acc, key) => (acc == null ? undefined : acc[key]), obj);
}
