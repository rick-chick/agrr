import { PendingToastRequest } from '../../core/view-effects/pending-toast-view.effects';
import { WorkRecordSaveToastResult } from '../../domain/plans/work-record-save-toast';

export function mapWorkRecordSaveToastToPendingRequest(
  toast: WorkRecordSaveToastResult
): PendingToastRequest {
  return {
    textKey: toast.textKey,
    textParams: toast.textParams,
    action: toast.navigation
      ? {
          labelKey: 'plans.work.toast.view_task_detail',
          routerLink: ['/plans', toast.navigation.planId, 'task_schedule'],
          queryParams: {
            field_cultivation_id: toast.navigation.fieldCultivationId,
            item_id: toast.navigation.taskScheduleItemId
          }
        }
      : undefined
  };
}
