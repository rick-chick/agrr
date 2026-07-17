import type { Params } from '@angular/router';

export interface MasterContextCrumb {
  /** i18n key for static labels (e.g. list title). */
  labelKey?: string;
  /** Literal label for dynamic content (e.g. entity name). */
  label?: string;
  /** Omit for the current-page crumb. */
  routerLink?: string | readonly unknown[];
  /** Optional query params for crumb links (e.g. plan wizard context). */
  queryParams?: Params | null;
}
