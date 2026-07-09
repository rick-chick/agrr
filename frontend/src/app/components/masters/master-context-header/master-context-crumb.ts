export interface MasterContextCrumb {
  /** i18n key for static labels (e.g. list title). */
  labelKey?: string;
  /** Literal label for dynamic content (e.g. entity name). */
  label?: string;
  /** Omit for the current-page crumb. */
  routerLink?: string | readonly unknown[];
}
