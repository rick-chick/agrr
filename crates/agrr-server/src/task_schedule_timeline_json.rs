//! JSON shape for `GET /api/v1/plans/:id/task_schedule` (Rails `TaskScheduleTimelineHtmlPresenter#as_json`).

use agrr_domain::cultivation_plan::dtos::{
    TaskScheduleTimeline, TaskScheduleTimelineAgriculturalTaskRead, TaskScheduleTimelineFieldRead,
    TaskScheduleTimelineScheduleItemRead, TaskScheduleTimelineTaskOptionRead,
    TaskScheduleTimelineWorkRecordSummaryRead,
};
use serde_json::{json, Map, Value};
use time::{Date, Duration, Weekday};

const WEEK_LENGTH_DAYS: i64 = 6;
const CATEGORY_GENERAL: &str = "general";
const CATEGORY_FERTILIZER: &str = "fertilizer";

pub fn to_json_body(timeline: TaskScheduleTimeline, query: TaskScheduleQuery) -> Value {
    let presenter = TimelineJsonPresenter::new(timeline, query);
    json!({
        "plan": presenter.plan_payload(),
        "week": presenter.week_payload(),
        "milestones": [],
        "fields": presenter.fields_payload(),
        "labels": json!({}),
        "minimap": presenter.minimap_payload(),
    })
}

pub struct TaskScheduleQuery {
    pub week_start: Option<String>,
    pub field_cultivation_id: Option<i64>,
    pub category: Option<String>,
}

struct TimelineJsonPresenter {
    timeline: TaskScheduleTimeline,
    query: TaskScheduleQuery,
    week_start: Date,
    week_end: Date,
}

impl TimelineJsonPresenter {
    fn new(timeline: TaskScheduleTimeline, query: TaskScheduleQuery) -> Self {
        let week_start = initial_week_start(&timeline, query.week_start.as_deref());
        let week_end = week_start + Duration::days(WEEK_LENGTH_DAYS);
        Self {
            timeline,
            query,
            week_start,
            week_end,
        }
    }

    fn today(&self) -> Date {
        self.timeline.today
    }

    fn week_range(&self) -> std::ops::RangeInclusive<Date> {
        self.week_start..=self.week_end
    }

    fn plan_payload(&self) -> Value {
        let plan = &self.timeline.plan;
        json!({
            "id": plan.id,
            "name": plan.display_name,
            "status": plan.status,
            "planning_start_date": plan.planning_start_date.map(|d| d.to_string()),
            "planning_end_date": plan.planning_end_date.map(|d| d.to_string()),
            "timeline_generated_at": plan.timeline_generated_at,
            "timeline_generated_at_display": plan.timeline_generated_at,
            "task_schedule_sync_state": plan.task_schedule_sync_state,
            "task_schedule_sync_error": plan.task_schedule_sync_error,
            "task_schedule_sync_error_crop_id": plan.task_schedule_sync_error_crop_id,
            "remediation_crops": self.remediation_crops_payload(),
        })
    }

    fn remediation_crops_payload(&self) -> Vec<Value> {
        let mut seen = std::collections::HashSet::new();
        let mut out = Vec::new();
        for field in &self.timeline.fields {
            if field.crop_id > 0 && seen.insert(field.crop_id) {
                out.push(json!({
                    "crop_id": field.crop_id,
                    "crop_name": field.crop_name,
                }));
            }
        }
        out
    }

    fn week_payload(&self) -> Value {
        json!({
            "start_date": self.week_start.to_string(),
            "end_date": self.week_end.to_string(),
            "label": format!("{} - {}", self.week_start, self.week_end),
            "days": self.days_payload(),
        })
    }

    fn days_payload(&self) -> Vec<Value> {
        let mut days = Vec::new();
        let mut d = self.week_start;
        while d <= self.week_end {
            days.push(json!({
                "date": d.to_string(),
                "weekday": weekday_key(d),
                "is_today": d == self.today(),
            }));
            d += Duration::days(1);
        }
        days
    }

    fn fields_payload(&self) -> Vec<Value> {
        self.filtered_fields()
            .iter()
            .filter_map(|field| self.serialize_field(field))
            .collect()
    }

    fn filtered_fields(&self) -> Vec<&TaskScheduleTimelineFieldRead> {
        let fields = &self.timeline.fields;
        match self.query.field_cultivation_id {
            Some(id) => fields
                .iter()
                .filter(|f| f.field_cultivation_id == id)
                .collect(),
            None => fields.iter().collect(),
        }
    }

    fn serialize_field(&self, field: &TaskScheduleTimelineFieldRead) -> Option<Value> {
        let mut categorized: Map<String, Value> = Map::new();
        categorized.insert(CATEGORY_GENERAL.to_string(), json!([]));
        categorized.insert(CATEGORY_FERTILIZER.to_string(), json!([]));
        categorized.insert("unscheduled".to_string(), json!([]));

        for schedule in &field.schedules {
            let category = schedule.category.as_str();
            if !self.include_category(category) {
                continue;
            }
            for item in &schedule.items {
                let serialized = self.serialize_item(item, category, field.field_cultivation_id);
                let scheduled_date = item
                    .scheduled_date
                    .as_deref()
                    .and_then(|s| Date::parse(s, &time::format_description::well_known::Iso8601::DATE).ok());
                if scheduled_date.is_none() {
                    categorized
                        .get_mut("unscheduled")
                        .unwrap()
                        .as_array_mut()
                        .unwrap()
                        .push(serialized);
                } else if self.week_range().contains(&scheduled_date.unwrap()) {
                    let bucket = if category == CATEGORY_FERTILIZER {
                        CATEGORY_FERTILIZER
                    } else {
                        CATEGORY_GENERAL
                    };
                    categorized
                        .get_mut(bucket)
                        .unwrap()
                        .as_array_mut()
                        .unwrap()
                        .push(serialized);
                }
            }
        }

        if categorized.values().all(|v| v.as_array().map(|a| a.is_empty()).unwrap_or(true))
            && !field.schedules.is_empty()
        {
            return None;
        }

        let task_options: Vec<Value> = field
            .task_options
            .iter()
            .map(task_option_payload)
            .collect();

        let mut field_info = json!({
            "id": field.id,
            "name": field.name,
            "crop_name": field.crop_name,
            "area_sqm": field.area_sqm,
            "field_cultivation_id": field.field_cultivation_id,
            "crop_id": field.crop_id,
            "task_options": task_options,
        });
        if let Some(obj) = field_info.as_object_mut() {
            obj.insert("schedules".to_string(), Value::Object(categorized));
        }
        Some(field_info)
    }

    fn serialize_item(
        &self,
        item: &TaskScheduleTimelineScheduleItemRead,
        category: &str,
        field_cultivation_id: i64,
    ) -> Value {
        let status = item.status.as_str();
        let work_records: Vec<Value> = item
            .work_records
            .iter()
            .map(work_record_payload)
            .collect();
        let mut payload = json!({
            "item_id": item.id,
            "name": item.name,
            "task_type": item.task_type,
            "category": category,
            "scheduled_date": item.scheduled_date,
            "stage_name": item.stage_name,
            "stage_order": item.stage_order,
            "gdd_trigger": optional_f64_as_string(item.gdd_trigger),
            "gdd_tolerance": optional_f64_as_string(item.gdd_tolerance),
            "priority": item.priority,
            "source": item.source,
            "weather_dependency": item.weather_dependency,
            "time_per_sqm": optional_f64_as_string(item.time_per_sqm),
            "amount": optional_f64_as_string(item.amount),
            "amount_unit": item.amount_unit,
            "status": status,
            "agricultural_task_id": item.agricultural_task_id,
            "field_cultivation_id": field_cultivation_id,
            "completed": item.completed,
            "work_records": work_records,
        });
        if let Some(obj) = payload.as_object_mut() {
            obj.insert("details".to_string(), detail_payload(item));
            obj.insert(
                "badge".to_string(),
                json!({
                    "type": item
                        .agricultural_task
                        .as_ref()
                        .and_then(|at| at.task_type.clone())
                        .unwrap_or_else(|| item.task_type.clone()),
                    "priority_level": priority_level(item.priority.map(i64::from)),
                    "status": status,
                    "category": category,
                }),
            );
        }
        payload
    }

    fn include_category(&self, category: &str) -> bool {
        match self.query.category.as_deref() {
            Some(CATEGORY_GENERAL) | Some(CATEGORY_FERTILIZER) => self.query.category.as_deref() == Some(category),
            _ => true,
        }
    }

    fn minimap_payload(&self) -> Value {
        let counts = minimap_counts(&self.timeline.scheduled_dates);
        let range = minimap_range(&self.timeline, &counts, self.today());
        let weeks: Vec<Value> = counts
            .keys()
            .filter(|d| counts[d] > 0)
            .map(|week_start| {
                let count = counts[week_start];
                json!({
                    "start_date": week_start.to_string(),
                    "label": week_start.to_string(),
                    "task_count": count,
                    "density": minimap_density(count),
                    "month_key": format!("{}-{:02}", week_start.year(), u8::from(week_start.month())),
                })
            })
            .collect();
        json!({
            "start_date": range.0.to_string(),
            "end_date": range.1.to_string(),
            "weeks": weeks,
        })
    }
}

fn task_option_payload(option: &TaskScheduleTimelineTaskOptionRead) -> Value {
    let mut payload = json!({
        "agricultural_task_id": option.agricultural_task_id,
        "template_id": option.agricultural_task_id,
        "name": option.name,
        "task_type": option.task_type,
    });
    if let Some(obj) = payload.as_object_mut() {
        if let Some(v) = &option.description {
            obj.insert("description".into(), json!(v));
        }
        if let Some(v) = &option.weather_dependency {
            obj.insert("weather_dependency".into(), json!(v));
        }
        if let Some(v) = option.time_per_sqm {
            obj.insert("time_per_sqm".into(), json!(v.to_string()));
        }
        if let Some(v) = &option.required_tools {
            obj.insert("required_tools".into(), json!(v));
        }
        if let Some(v) = &option.skill_level {
            obj.insert("skill_level".into(), json!(v));
        }
    }
    payload
}

fn work_record_payload(record: &TaskScheduleTimelineWorkRecordSummaryRead) -> Value {
    json!({
        "id": record.id,
        "actual_date": record.actual_date,
        "notes": record.notes,
    })
}

fn agricultural_task_payload(task: &TaskScheduleTimelineAgriculturalTaskRead) -> Value {
    let mut payload = json!({ "name": task.name });
    if let Some(obj) = payload.as_object_mut() {
        if let Some(v) = &task.description {
            obj.insert("description".into(), json!(v));
        }
        if let Some(v) = task.time_per_sqm {
            obj.insert("time_per_sqm".into(), json!(v.to_string()));
        }
        if let Some(v) = &task.weather_dependency {
            obj.insert("weather_dependency".into(), json!(v));
        }
        if let Some(v) = &task.required_tools {
            obj.insert("required_tools".into(), json!(v));
        }
        if let Some(v) = &task.skill_level {
            obj.insert("skill_level".into(), json!(v));
        }
        if let Some(v) = &task.task_type {
            obj.insert("task_type".into(), json!(v));
        }
    }
    payload
}

fn detail_payload(item: &TaskScheduleTimelineScheduleItemRead) -> Value {
    json!({
        "stage": {
            "name": item.stage_name,
            "order": item.stage_order,
        },
        "gdd": {
            "trigger": optional_f64_as_string(item.gdd_trigger),
            "tolerance": optional_f64_as_string(item.gdd_tolerance),
        },
        "priority": item.priority,
        "weather_dependency": item.weather_dependency,
        "time_per_sqm": optional_f64_as_string(item.time_per_sqm),
        "amount": optional_f64_as_string(item.amount),
        "amount_unit": item.amount_unit,
        "source": item.source,
        "master": item
            .agricultural_task
            .as_ref()
            .map(agricultural_task_payload)
            .unwrap_or(Value::Null),
        "history": {
            "rescheduled_at": item.rescheduled_at,
            "cancelled_at": item.cancelled_at,
        },
    })
}

fn optional_f64_as_string(value: Option<f64>) -> Value {
    value.map(|v| json!(v.to_string())).unwrap_or(Value::Null)
}

fn priority_level(value: Option<i64>) -> &'static str {
    match value {
        None => "priority-none",
        Some(0) | Some(1) => "priority-high",
        Some(2) => "priority-medium",
        _ => "priority-low",
    }
}

fn weekday_key(d: Date) -> &'static str {
    match d.weekday() {
        Weekday::Monday => "mon",
        Weekday::Tuesday => "tue",
        Weekday::Wednesday => "wed",
        Weekday::Thursday => "thu",
        Weekday::Friday => "fri",
        Weekday::Saturday => "sat",
        Weekday::Sunday => "sun",
    }
}

fn beginning_of_week(d: Date) -> Date {
    let days_from_monday = match d.weekday() {
        Weekday::Monday => 0,
        Weekday::Tuesday => 1,
        Weekday::Wednesday => 2,
        Weekday::Thursday => 3,
        Weekday::Friday => 4,
        Weekday::Saturday => 5,
        Weekday::Sunday => 6,
    };
    d - Duration::days(days_from_monday)
}

fn initial_week_start(timeline: &TaskScheduleTimeline, week_start_param: Option<&str>) -> Date {
    if let Some(s) = week_start_param {
        if let Ok(d) = Date::parse(s, &time::format_description::well_known::Iso8601::DATE) {
            return beginning_of_week(d);
        }
    }
    let today = timeline.today;
    let counts = minimap_counts(&timeline.scheduled_dates);
    if counts.is_empty() {
        return beginning_of_week(today);
    }
    let today_week = beginning_of_week(today);
    let upcoming = counts.keys().filter(|d| **d >= today_week).min().copied();
    let target = upcoming.or_else(|| counts.keys().min().copied()).unwrap_or(today);
    beginning_of_week(target)
}

fn minimap_counts(dates: &[Date]) -> std::collections::BTreeMap<Date, i64> {
    let mut counts = std::collections::BTreeMap::new();
    for date in dates {
        let week = beginning_of_week(*date);
        *counts.entry(week).or_insert(0) += 1;
    }
    counts
}

fn minimap_density(count: i64) -> &'static str {
    match count {
        0 => "none",
        1..=2 => "low",
        3..=5 => "medium",
        _ => "high",
    }
}

fn minimap_range(
    timeline: &TaskScheduleTimeline,
    counts: &std::collections::BTreeMap<Date, i64>,
    today: Date,
) -> (Date, Date) {
    let mut start_candidates = vec![today];
    if let Some(d) = timeline.plan.planning_start_date {
        start_candidates.push(d);
    }
    if let Some(min) = counts.keys().min() {
        start_candidates.push(*min);
    }
    let mut end_candidates = vec![today];
    if let Some(d) = timeline.plan.planning_end_date {
        end_candidates.push(d);
    }
    if let Some(max) = counts.keys().max() {
        end_candidates.push(*max);
    }
    let start = start_candidates.into_iter().min().unwrap_or(today);
    let end = end_candidates.into_iter().max().unwrap_or(today);
    (beginning_of_week(start), beginning_of_week(end) + Duration::days(WEEK_LENGTH_DAYS))
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::cultivation_plan::dtos::{
        TaskScheduleTimeline, TaskScheduleTimelineFieldRead, TaskScheduleTimelinePlanRead,
        TaskScheduleTimelineScheduleItemRead, TaskScheduleTimelineScheduleRead,
        TaskScheduleTimelineTaskOptionRead,
    };
    use time::{Date, Month};

    fn sample_plan() -> TaskScheduleTimelinePlanRead {
        TaskScheduleTimelinePlanRead {
            id: 1,
            display_name: "Plan".into(),
            status: "completed".into(),
            planning_start_date: None,
            planning_end_date: None,
            timeline_generated_at: None,
            farm_display_name: "Farm".into(),
            total_area: 50.0,
            task_schedule_sync_state: "failed".into(),
            task_schedule_sync_error: Some(
                "plans.task_schedules.sync_errors.generic".into(),
            ),
            task_schedule_sync_error_crop_id: None,
        }
    }

    #[test]
    fn fields_payload_includes_crops_when_schedules_not_generated() {
        let today = Date::from_calendar_date(2026, Month::July, 4).expect("date");
        let timeline = TaskScheduleTimeline {
            plan: sample_plan(),
            fields: vec![TaskScheduleTimelineFieldRead {
                id: 10,
                name: "F1".into(),
                crop_name: "Tomato".into(),
                area_sqm: 50.0,
                field_cultivation_id: 10,
                crop_id: 42,
                task_options: vec![],
                schedules: vec![],
            }],
            scheduled_dates: vec![],
            today,
        };
        let body = to_json_body(
            timeline,
            TaskScheduleQuery {
                week_start: None,
                field_cultivation_id: None,
                category: None,
            },
        );
        let fields = body["fields"].as_array().expect("fields");
        assert_eq!(1, fields.len());
        assert_eq!(42, fields[0]["crop_id"].as_i64().unwrap());
        assert_eq!("Tomato", fields[0]["crop_name"].as_str().unwrap());
        let remediation = body["plan"]["remediation_crops"]
            .as_array()
            .expect("remediation_crops");
        assert_eq!(1, remediation.len());
        assert_eq!(42, remediation[0]["crop_id"].as_i64().unwrap());
    }

    #[test]
    fn detail_payload_omits_legacy_actual_fields() {
        let item = TaskScheduleTimelineScheduleItemRead {
            id: 1,
            name: "task".into(),
            task_type: "field_work".into(),
            scheduled_date: None,
            stage_name: Some("s".into()),
            stage_order: Some(1),
            gdd_trigger: Some(0.0),
            gdd_tolerance: Some(0.0),
            priority: Some(1),
            source: "agrr".into(),
            weather_dependency: Some("low".into()),
            time_per_sqm: Some(1.0),
            amount: Some(1.0),
            amount_unit: Some("kg".into()),
            status: "planned".into(),
            agricultural_task_id: None,
            field_cultivation_id: 10,
            agricultural_task: None,
            rescheduled_at: None,
            cancelled_at: None,
            completed: false,
            work_records: vec![],
        };
        let details = detail_payload(&item);
        assert!(details.get("actual").is_none());
        let history = details.get("history").unwrap().as_object().unwrap();
        assert!(!history.contains_key("completed_at"));
        assert!(history.contains_key("rescheduled_at"));
        assert!(history.contains_key("cancelled_at"));
    }

    #[test]
    fn task_option_payload_includes_template_id_alias() {
        let payload = task_option_payload(&TaskScheduleTimelineTaskOptionRead {
            agricultural_task_id: 501,
            name: "Weeding".into(),
            task_type: "field_work".into(),
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
            required_tools: None,
            skill_level: None,
        });
        assert_eq!(501, payload["agricultural_task_id"].as_i64().unwrap());
        assert_eq!(501, payload["template_id"].as_i64().unwrap());
    }

    #[test]
    fn fields_payload_serializes_scheduled_items_in_week() {
        let today = Date::from_calendar_date(2026, Month::July, 5).expect("date");
        let timeline = TaskScheduleTimeline {
            plan: sample_plan(),
            fields: vec![TaskScheduleTimelineFieldRead {
                id: 10,
                name: "F1".into(),
                crop_name: "Tomato".into(),
                area_sqm: 50.0,
                field_cultivation_id: 10,
                crop_id: 42,
                task_options: vec![],
                schedules: vec![TaskScheduleTimelineScheduleRead {
                    category: "general".into(),
                    items: vec![TaskScheduleTimelineScheduleItemRead {
                        id: 1001,
                        name: "Weed".into(),
                        task_type: "field_work".into(),
                        scheduled_date: Some("2026-07-05".into()),
                        stage_name: None,
                        stage_order: None,
                        gdd_trigger: None,
                        gdd_tolerance: None,
                        priority: None,
                        source: "agrr".into(),
                        weather_dependency: None,
                        time_per_sqm: None,
                        amount: None,
                        amount_unit: None,
                        status: "planned".into(),
                        agricultural_task_id: Some(501),
                        field_cultivation_id: 10,
                        agricultural_task: None,
                        rescheduled_at: None,
                        cancelled_at: None,
                        completed: false,
                        work_records: vec![],
                    }],
                }],
            }],
            scheduled_dates: vec![today],
            today,
        };
        let body = to_json_body(
            timeline,
            TaskScheduleQuery {
                week_start: Some("2026-07-05".into()),
                field_cultivation_id: None,
                category: None,
            },
        );
        let fields = body["fields"].as_array().expect("fields");
        assert_eq!(1, fields.len());
        let general = fields[0]["schedules"]["general"]
            .as_array()
            .expect("general");
        assert_eq!(1, general.len());
        assert_eq!(1001, general[0]["item_id"].as_i64().unwrap());
    }
}
