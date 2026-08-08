function isPdfFile(file) {
  const mime = String(file?.mimeType || "").toLowerCase();
  const url = String(file?.url || "").toLowerCase();
  return mime.includes("pdf") || url.endsWith(".pdf");
}

export function normalizeCertificateFiles(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((file) => file && typeof file === "object")
    .map((file) => ({
      url: String(file.url || "").trim(),
      fileName: String(file.fileName || "").trim(),
      mimeType: String(file.mimeType || "").trim(),
      uploadedAt: file.uploadedAt || null,
    }))
    .filter((file) => file.url);
}

/** Prefer the first non-empty certificate list among sources. */
export function pickCertificateFiles(...sources) {
  for (const source of sources) {
    const files = normalizeCertificateFiles(source);
    if (files.length) return files;
  }
  return [];
}

/**
 * Gallery of uploaded coach certificate images / PDFs.
 */
export default function CertificateFilesGallery({
  files,
  emptyLabel = "No certificate files uploaded.",
  title = "Certificate files",
  className = "",
  /** When true, always show the section title (even if empty). */
  showTitleWhenEmpty = false,
}) {
  const items = normalizeCertificateFiles(files);

  if (!items.length) {
    if (!emptyLabel && !showTitleWhenEmpty) return null;
    return (
      <div className={className}>
        {title && showTitleWhenEmpty ? (
          <p className="mb-2 text-sm font-semibold text-[var(--vf-text)]">{title}</p>
        ) : null}
        {emptyLabel ? (
          <p className="rounded-[12px] border border-dashed border-[var(--vf-border)] bg-[var(--vf-surface-muted)] px-3 py-4 text-sm text-[var(--vf-muted)]">
            {emptyLabel}
          </p>
        ) : null}
      </div>
    );
  }

  return (
    <div className={className}>
      {(title || items.length) ? (
        <div className="mb-2 flex items-center justify-between gap-2">
          {title ? (
            <p className="text-sm font-semibold text-[var(--vf-text)]">{title}</p>
          ) : (
            <span />
          )}
          <span className="text-xs text-[var(--vf-muted)]">
            {items.length} file{items.length === 1 ? "" : "s"} · click to open
          </span>
        </div>
      ) : null}
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {items.map((file, index) => {
          const name = file.fileName || `Certificate ${index + 1}`;
          const pdf = isPdfFile(file);
          return (
            <a
              key={`${file.url}-${index}`}
              href={file.url}
              target="_blank"
              rel="noreferrer"
              className="group overflow-hidden rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface)] transition hover:border-[var(--vf-primary)]"
              title={name}
            >
              {pdf ? (
                <div className="flex h-36 flex-col items-center justify-center gap-1 px-2 text-center">
                  <span className="text-xs font-semibold text-[var(--vf-danger)]">PDF</span>
                  <span className="line-clamp-2 text-xs text-[var(--vf-muted)]">{name}</span>
                  <span className="text-[10px] font-medium text-[var(--vf-primary)]">Open / download</span>
                </div>
              ) : (
                <div className="relative">
                  <img
                    src={file.url}
                    alt={name}
                    className="h-36 w-full bg-[var(--vf-surface-muted)] object-cover"
                    onError={(event) => {
                      event.currentTarget.style.display = "none";
                      const fallback = event.currentTarget.nextElementSibling;
                      if (fallback) fallback.hidden = false;
                    }}
                  />
                  <div
                    hidden
                    className="flex h-36 flex-col items-center justify-center gap-1 px-2 text-center"
                  >
                    <span className="text-xs font-semibold text-[var(--vf-text)]">Image</span>
                    <span className="line-clamp-2 text-xs text-[var(--vf-muted)]">{name}</span>
                    <span className="text-[10px] font-medium text-[var(--vf-primary)]">Open in new tab</span>
                  </div>
                  <span className="absolute inset-x-0 bottom-0 truncate bg-black/55 px-2 py-1 text-[10px] text-white opacity-0 transition group-hover:opacity-100">
                    {name}
                  </span>
                </div>
              )}
            </a>
          );
        })}
      </div>
    </div>
  );
}
