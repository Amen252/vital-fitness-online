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
}) {
  const items = normalizeCertificateFiles(files);

  if (!items.length) {
    return emptyLabel ? (
      <p className={`text-sm text-[var(--vf-muted)] ${className}`.trim()}>{emptyLabel}</p>
    ) : null;
  }

  return (
    <div className={className}>
      {title ? (
        <p className="mb-2 text-sm font-semibold text-[var(--vf-text)]">{title}</p>
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
              className="overflow-hidden rounded-[12px] border border-[var(--vf-border)] bg-[var(--vf-surface)] transition hover:border-[var(--vf-primary)]"
              title={name}
            >
              {pdf ? (
                <div className="flex h-28 flex-col items-center justify-center gap-1 px-2 text-center">
                  <span className="text-xs font-semibold text-[var(--vf-danger)]">PDF</span>
                  <span className="line-clamp-2 text-xs text-[var(--vf-muted)]">{name}</span>
                  <span className="text-[10px] font-medium text-[var(--vf-primary)]">Open / download</span>
                </div>
              ) : (
                <img src={file.url} alt={name} className="h-28 w-full object-cover" />
              )}
            </a>
          );
        })}
      </div>
    </div>
  );
}
