import { TranslateService } from '@ngx-translate/core';
import { HOME_DEMO_SECTION_I18N_KEYS } from '../../domain/plans/landing-demo-i18n.keys';

export { HOME_DEMO_SECTION_I18N_KEYS as HOME_DEMO_TITLE_I18N };

export function buildHomeDemoTitle(
  translate: Pick<TranslateService, 'instant'>
): string {
  const schedule = translate.instant(HOME_DEMO_SECTION_I18N_KEYS.schedule);
  const preview = translate.instant(HOME_DEMO_SECTION_I18N_KEYS.preview);
  const separator = translate.instant(HOME_DEMO_SECTION_I18N_KEYS.separator);
  return translate.instant(HOME_DEMO_SECTION_I18N_KEYS.title, {
    schedule,
    preview,
    separator
  });
}
