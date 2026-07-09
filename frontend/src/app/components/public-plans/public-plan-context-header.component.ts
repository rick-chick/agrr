import { Component, Input } from '@angular/core';
import { MasterContextHeaderComponent } from '../masters/master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../masters/master-context-header/master-context-crumb';

@Component({
  selector: 'app-public-plan-context-header',
  standalone: true,
  imports: [MasterContextHeaderComponent],
  template: `<app-master-context-header [crumbs]="crumbs" />`
})
export class PublicPlanContextHeaderComponent {
  @Input({ required: true }) crumbs!: MasterContextCrumb[];
}
