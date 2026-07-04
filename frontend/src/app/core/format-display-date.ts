/** Maps ngx-translate app language to BCP 47 for Intl date formatting. */
export function appLangToBcp47(lang: string): string {
  switch (lang) {
    case 'ja':
      return 'ja-JP';
    case 'in':
      return 'hi-IN';
    case 'en':
    default:
      return 'en-US';
  }
}

/** Formats YYYY-MM-DD for display in the user's app language. */
export function formatIsoDateForDisplay(iso: string, lang: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
  if (!match) {
    return iso;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(year, month - 1, day);
  if (Number.isNaN(date.getTime())) {
    return iso;
  }
  return new Intl.DateTimeFormat(appLangToBcp47(lang), {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  }).format(date);
}

function parseAppDateTime(value: string): Date | null {
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (dateOnly) {
    const date = new Date(Number(dateOnly[1]), Number(dateOnly[2]) - 1, Number(dateOnly[3]));
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const sqlite = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/.exec(value);
  if (sqlite) {
    const date = new Date(
      Number(sqlite[1]),
      Number(sqlite[2]) - 1,
      Number(sqlite[3]),
      Number(sqlite[4]),
      Number(sqlite[5]),
      Number(sqlite[6])
    );
    return Number.isNaN(date.getTime()) ? null : date;
  }

  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

/** Formats ISO/SQLite timestamps for display in the user's app language. */
export function formatIsoDateTimeForDisplay(value: string, lang: string): string {
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (dateOnly) {
    return formatIsoDateForDisplay(value, lang);
  }

  const date = parseAppDateTime(value);
  if (!date) {
    return value;
  }

  return new Intl.DateTimeFormat(appLangToBcp47(lang), {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit'
  }).format(date);
}

/** Formats YYYY-MM for display in the user's app language. */
export function formatIsoMonthForDisplay(isoYm: string, lang: string): string {
  const match = /^(\d{4})-(\d{2})$/.exec(isoYm);
  if (!match) {
    return isoYm;
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const date = new Date(year, month - 1, 1);
  if (Number.isNaN(date.getTime())) {
    return isoYm;
  }
  return new Intl.DateTimeFormat(appLangToBcp47(lang), {
    year: 'numeric',
    month: 'long'
  }).format(date);
}
