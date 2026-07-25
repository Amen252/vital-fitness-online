/**
 * Normalize a coach-entered media URL so members can open it reliably.
 * - Trims whitespace
 * - Adds https:// when the scheme is missing (youtube/vimeo/www/host-like values)
 * - Returns '' for empty / unusable values
 */
function normalizeMediaUrl(raw) {
  const value = String(raw || '').trim();
  if (!value) return '';

  const lower = value.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return value;
  }

  if (
    lower.startsWith('www.')
    || lower.includes('youtube.com')
    || lower.includes('youtu.be')
    || lower.includes('vimeo.com')
    || (/^[a-z0-9.-]+\.[a-z]{2,}/i.test(value) && !value.includes(' '))
  ) {
    return `https://${value}`;
  }

  return '';
}

module.exports = { normalizeMediaUrl };
