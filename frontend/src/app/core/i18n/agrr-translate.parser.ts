import { Injectable } from '@angular/core';
import { TranslateDefaultParser } from '@ngx-translate/core';

/**
 * ngx-translate only replaces `{{param}}`. Rails-synced catalogs may still use `%{param}`.
 * Accept both so master edit titles and undo toasts interpolate in every locale.
 */
@Injectable()
export class AgrrTranslateParser extends TranslateDefaultParser {
  override interpolateString(expr: string, params?: object): string {
    const withNgx = super.interpolateString(expr, params);
    if (!params || typeof withNgx !== 'string') {
      return withNgx;
    }

    return Object.entries(params as Record<string, unknown>).reduce((text, [key, value]) => {
      if (value === null || value === undefined) {
        return text;
      }
      const replacement = this.formatValue(value);
      return text.replaceAll(`%{${key}}`, replacement);
    }, withNgx);
  }
}
