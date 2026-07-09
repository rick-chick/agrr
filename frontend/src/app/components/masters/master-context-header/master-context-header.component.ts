import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { MasterContextCrumb } from './master-context-crumb';

@Component({
  selector: 'app-master-context-header',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <header class="page-header page-header--compact master-context-header">
      <nav class="master-context-header__nav" aria-label="Breadcrumb">
        <ol class="master-context-header__crumbs">
          @for (crumb of crumbs; track $index; let first = $first) {
            <li class="master-context-header__crumb">
              @if (crumb.routerLink != null) {
                <a
                  [routerLink]="crumb.routerLink"
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
    </header>
  `,
  styleUrls: ['./master-context-header.component.css']
})
export class MasterContextHeaderComponent {
  @Input({ required: true }) crumbs: MasterContextCrumb[] = [];
}
