/** i18n keys for gantt chart UI (component template + presenter). Kept in sync with gantt-locale.catalog.spec. */
export const GANTT_I18N_KEYS = {
  optimizing: 'plans.gantt.optimizing',
  range: {
    prevMonth: 'plans.gantt.range.prev_month',
    nextMonth: 'plans.gantt.range.next_month'
  },
  noPlanData: 'plans.gantt.no_plan_data',
  noFieldData: 'plans.gantt.no_field_data',
  noData: 'plans.gantt.no_data',
  adjustFailed: 'plans.gantt.adjust_failed',
  trashDropLabel: 'plans.gantt.trash_drop_label',
  labels: {
    year: 'plans.gantt.labels.year',
    month: 'plans.gantt.labels.month',
    day: 'plans.gantt.labels.day',
    week: 'plans.gantt.labels.week',
    quarter: 'plans.gantt.labels.quarter'
  },
  mobile: {
    moreActions: 'plans.gantt.mobile.more_actions',
    fieldColumnShort: 'plans.gantt.mobile.field_column_short',
    fieldLegendButton: 'plans.gantt.mobile.field_legend_button',
    fieldLegendTitle: 'plans.gantt.mobile.field_legend_title',
    fieldLegendItem: 'plans.gantt.mobile.field_legend_item',
    fieldLegendDelete: 'plans.gantt.mobile.field_legend_delete',
    dragTargetField: 'plans.gantt.mobile.drag_target_field'
  },
  js: {
    addCropButton: 'js.gantt.add_crop_button',
    cropPaletteCancel: 'js.gantt.crop_palette_cancel',
    addFieldButton: 'js.gantt.add_field_button',
    cropPaletteTitle: 'js.gantt.crop_palette_title',
    cropPaletteNoCrops: 'js.gantt.crop_palette_no_crops',
    fieldFormNameLabel: 'js.gantt.field_form_name_label',
    fieldFormNamePlaceholder: 'js.gantt.field_form_name_placeholder',
    fieldFormAreaLabel: 'js.gantt.field_form_area_label',
    fieldFormAreaPlaceholder: 'js.gantt.field_form_area_placeholder',
    fieldFormSubmit: 'js.gantt.field_form_submit',
    addingFieldLoading: 'js.gantt.adding_field_loading',
    logs: {
      dataRefetchFailed: 'js.gantt.logs.data_refetch_failed',
      dataRefetchApiError: 'js.gantt.logs.data_refetch_api_error'
    },
    confirmDeleteCrop: 'js.gantt.confirm_delete_crop',
    confirmDeleteField: 'js.gantt.confirm_delete_field'
  },
  sharedNavbarFarms: 'shared.navbar.farms'
} as const;

/** Flat list for locale catalog tests. */
export const GANTT_I18N_KEY_PATHS: readonly string[] = [
  GANTT_I18N_KEYS.optimizing,
  GANTT_I18N_KEYS.range.prevMonth,
  GANTT_I18N_KEYS.range.nextMonth,
  GANTT_I18N_KEYS.noPlanData,
  GANTT_I18N_KEYS.noFieldData,
  GANTT_I18N_KEYS.noData,
  GANTT_I18N_KEYS.adjustFailed,
  GANTT_I18N_KEYS.trashDropLabel,
  GANTT_I18N_KEYS.labels.year,
  GANTT_I18N_KEYS.labels.month,
  GANTT_I18N_KEYS.labels.day,
  GANTT_I18N_KEYS.labels.week,
  GANTT_I18N_KEYS.labels.quarter,
  GANTT_I18N_KEYS.js.addCropButton,
  GANTT_I18N_KEYS.js.cropPaletteCancel,
  GANTT_I18N_KEYS.js.addFieldButton,
  GANTT_I18N_KEYS.js.cropPaletteTitle,
  GANTT_I18N_KEYS.js.cropPaletteNoCrops,
  GANTT_I18N_KEYS.js.fieldFormNameLabel,
  GANTT_I18N_KEYS.js.fieldFormNamePlaceholder,
  GANTT_I18N_KEYS.js.fieldFormAreaLabel,
  GANTT_I18N_KEYS.js.fieldFormAreaPlaceholder,
  GANTT_I18N_KEYS.js.fieldFormSubmit,
  GANTT_I18N_KEYS.js.addingFieldLoading,
  GANTT_I18N_KEYS.mobile.moreActions,
  GANTT_I18N_KEYS.mobile.fieldColumnShort,
  GANTT_I18N_KEYS.mobile.fieldLegendButton,
  GANTT_I18N_KEYS.mobile.fieldLegendTitle,
  GANTT_I18N_KEYS.mobile.fieldLegendItem,
  GANTT_I18N_KEYS.mobile.fieldLegendDelete,
  GANTT_I18N_KEYS.mobile.dragTargetField,
  GANTT_I18N_KEYS.js.logs.dataRefetchFailed,
  GANTT_I18N_KEYS.js.logs.dataRefetchApiError,
  GANTT_I18N_KEYS.js.confirmDeleteCrop,
  GANTT_I18N_KEYS.js.confirmDeleteField,
  GANTT_I18N_KEYS.sharedNavbarFarms
];
