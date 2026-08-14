import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';

@Component({
  selector: 'app-learn-proposal-evidence-panel',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (evidence) {
      <div class="learn-proposal-evidence">
        <button
          type="button"
          class="learn-proposal-evidence__toggle"
          [attr.aria-expanded]="expanded"
          (click)="expanded = !expanded"
        >
          {{ toggleLabelKey | translate }}
        </button>
        @if (expanded) {
          <div class="learn-proposal-evidence__panel">
            <p class="learn-proposal-evidence__rationale">
              {{
                rationaleKey
                  | translate
                    : {
                        count: evidence.exceedanceCount,
                        threshold: evidence.thresholdValue,
                        total: evidence.totalRecordedCount
                      }
              }}
            </p>
            @if (evidence.contributingRecords.length > 0) {
              <p class="learn-proposal-evidence__records-title">
                {{ recordsTitleKey | translate }}
              </p>
              <ul class="learn-proposal-evidence__records">
                @for (record of evidence.contributingRecords; track record.name + record.actualDate) {
                  <li class="learn-proposal-evidence__record">
                    {{
                      recordLabelKey
                        | translate: { name: record.name, date: formatDate(record.actualDate) }
                    }}
                  </li>
                }
              </ul>
            }
          </div>
        }
      </div>
    }
  `,
  styleUrls: ['./learn-proposal-evidence-panel.component.css']
})
export class LearnProposalEvidencePanelComponent {
  @Input() evidence: LearnProposalEvidence | null = null;
  @Input({ required: true }) toggleLabelKey!: string;
  @Input({ required: true }) rationaleKey!: string;
  @Input({ required: true }) recordsTitleKey!: string;
  @Input({ required: true }) recordLabelKey!: string;

  expanded = false;

  formatDate(value: string | null): string {
    return value ?? '—';
  }
}
