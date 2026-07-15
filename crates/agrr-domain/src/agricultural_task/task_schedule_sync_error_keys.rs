//! i18n keys for task schedule generation failures (stored in API / Cable / DB).

pub const MISSING_WEATHER: &str = "plans.task_schedules.sync_errors.missing_weather";
/// Legacy stored value; generation no longer emits this key (blueprint-only gate).
pub const MISSING_CROP_TEMPLATES: &str = "plans.task_schedules.sync_errors.missing_crop_templates";
pub const MISSING_CROP_BLUEPRINTS: &str = "plans.task_schedules.sync_errors.missing_crop_blueprints";
pub const MISSING_GENERAL_BLUEPRINTS: &str =
    "plans.task_schedules.sync_errors.missing_general_blueprints";
/// Legacy alias kept for stored sync errors written before blueprint-only migration.
pub const MISSING_GENERAL_TEMPLATES: &str = "plans.task_schedules.sync_errors.missing_general_templates";
pub const EMPTY_GDD_PROGRESS: &str = "plans.task_schedules.sync_errors.empty_gdd_progress";
pub const MISSING_GDD_TRIGGER: &str = "plans.task_schedules.sync_errors.missing_gdd_trigger";
pub const GDD_DATE_NOT_FOUND: &str = "plans.task_schedules.sync_errors.gdd_date_not_found";
pub const MISSING_START_DATE: &str = "plans.task_schedules.sync_errors.missing_start_date";
pub const MISSING_FIELD_CROP: &str = "plans.task_schedules.sync_errors.missing_field_crop";
pub const AGRR_UNAVAILABLE: &str = "plans.task_schedules.sync_errors.agrr_unavailable";
pub const GENERIC: &str = "plans.task_schedules.sync_errors.generic";
