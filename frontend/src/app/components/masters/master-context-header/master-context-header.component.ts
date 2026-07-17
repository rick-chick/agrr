import { Component, Input } from '@angular/core';
import { Params, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { MasterContextCrumb } from './master-context-crumb';

@Component({
  selector: 'app-master-context-header',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <header class="page-header page-header--compact master-context-header">
      <div class="master-context-header__bar">
        <nav class="master-context-header__nav" aria-label="Breadcrumb">
          <ol class="master-context-header__crumbs">
            @for (crumb of crumbs; track $index; let first = $first) {
              <li class="master-context-header__crumb">
                @if (crumb.routerLink != null) {
                  <a
                    [routerLink]="crumb.routerLink"
                    [queryParams]="crumb.queryParams"
                    [class.master-context-header__back]="first"
                    [class.master-context-header__link]="!first"
                  >
                    @if (crumb.labelKey) {
                      {{ crumb.labelKey | translate }}
                    } @else {
                      {{ crumb.label }}
                    }
                  </a>
                } @else {
                  <span class="master-context-header__current" aria-current="page">
                    @if (crumb.labelKey) {
                      {{ crumb.labelKey | translate }}
                    } @else {
                      {{ crumb.label }}
                    }
                  </span>
                }
              </li>
            }
          </ol>
        </nav>
        @if (forwardRouterLink != null) {
          <a
            class="master-context-header__forward"
            [routerLink]="forwardRouterLink"
            [queryParams]="forwardQueryParams"
          >
            @if (forwardLabelKey) {
              {{ forwardLabelKey | translate }}
            }
          </a>
        }
      </div>
    </header>
  `,
  styleUrls: ['./master-context-header.component.css']
})
export class MasterContextHeaderComponent {
  @Input({ required: true }) crumbs: MasterContextCrumb[] = [];
  @Input() forwardRouterLink: string | readonly unknown[] | null = null;
  @Input() forwardQueryParams: Params | null = null;
  @Input() forwardLabelKey?: string;
}
