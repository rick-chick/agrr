import { Pipe, PipeTransform } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';

import { localizePlanDisplayName } from './plan-display-name';

@Pipe({
  name: 'planDisplayName',
  standalone: true,
  pure: false
})
export class PlanDisplayNamePipe implements PipeTransform {
  constructor(private readonly translate: TranslateService) {}

  transform(storedName: string | null | undefined): string {
    return localizePlanDisplayName(storedName, (key, params) =>
      this.translate.instant(key, params)
    );
  }
}
