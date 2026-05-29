//! JSON shape for `GET /api/v1/plans/:id/task_schedule` (Rails `TaskScheduleTimelineHtmlPresenter#as_json`).

use agrr_domain::cultivation_plan::dtos::{
    TaskScheduleTimeline, TaskScheduleTimelineFieldRead,
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
        })
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
            let category = schedule
                .get("category")
                .and_then(|v| v.as_str())
                .unwrap_or(CATEGORY_GENERAL);
            if !self.include_category(category) {
                continue;
            }
            let items = schedule.get("items").and_then(|v| v.as_array());
            let Some(items) = items else { continue };
            for item in items {
                let serialized = self.serialize_item(item, category, field.field_cultivation_id);
                let scheduled_date = item
                    .get("scheduled_date")
                    .and_then(|v| v.as_str())
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

        if categorized.values().all(|v| v.as_array().map(|a| a.is_empty()).unwrap_or(true)) {
            return None;
        }

        let mut field_info = json!({
            "id": field.id,
            "name": field.name,
            "crop_name": field.crop_name,
            "area_sqm": field.area_sqm,
            "field_cultivation_id": field.field_cultivation_id,
            "crop_id": field.crop_id,
            "task_options": field.task_options,
        });
        if let Some(obj) = field_info.as_object_mut() {
            obj.insert("schedules".to_string(), Value::Object(categorized));
        }
        Some(field_info)
    }

    fn serialize_item(&self, item: &Value, category: &str, field_cultivation_id: i64) -> Value {
        let id = item.get("id").and_then(|v| v.as_i64()).unwrap_or(0);
        let status = item
            .get("status")
            .and_then(|v| v.as_str())
            .unwrap_or("planned");
        let mut payload = json!({
            "item_id": id,
            "name": item.get("name").cloned().unwrap_or(Value::Null),
            "task_type": item.get("task_type").cloned().unwrap_or(Value::Null),
            "category": category,
            "scheduled_date": item.get("scheduled_date").cloned().unwrap_or(Value::Null),
            "stage_name": item.get("stage_name").cloned().unwrap_or(Value::Null),
            "stage_order": item.get("stage_order").cloned().unwrap_or(Value::Null),
            "gdd_trigger": item.get("gdd_trigger").cloned().unwrap_or(Value::Null),
            "gdd_tolerance": item.get("gdd_tolerance").cloned().unwrap_or(Value::Null),
            "priority": item.get("priority").cloned().unwrap_or(Value::Null),
            "source": item.get("source").cloned().unwrap_or(Value::Null),
            "weather_dependency": item.get("weather_dependency").cloned().unwrap_or(Value::Null),
            "time_per_sqm": item.get("time_per_sqm").cloned().unwrap_or(Value::Null),
            "amount": item.get("amount").cloned().unwrap_or(Value::Null),
            "amount_unit": item.get("amount_unit").cloned().unwrap_or(Value::Null),
            "status": status,
            "agricultural_task_id": item.get("agricultural_task_id").cloned().unwrap_or(Value::Null),
            "field_cultivation_id": field_cultivation_id,
        });
        if let Some(obj) = payload.as_object_mut() {
            obj.insert("details".to_string(), detail_payload(item));
            obj.insert(
                "badge".to_string(),
                json!({
                    "type": item.pointer("/agricultural_task/task_type")
                        .or_else(|| item.get("task_type"))
                        .cloned()
                        .unwrap_or(Value::Null),
                    "priority_level": priority_level(item.get("priority").and_then(|v| v.as_i64())),
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

fn detail_payload(item: &Value) -> Value {
    json!({
        "stage": {
            "name": item.get("stage_name").cloned().unwrap_or(Value::Null),
            "order": item.get("stage_order").cloned().unwrap_or(Value::Null),
        },
        "gdd": {
            "trigger": item.get("gdd_trigger").cloned().unwrap_or(Value::Null),
            "tolerance": item.get("gdd_tolerance").cloned().unwrap_or(Value::Null),
        },
        "priority": item.get("priority").cloned().unwrap_or(Value::Null),
        "weather_dependency": item.get("weather_dependency").cloned().unwrap_or(Value::Null),
        "time_per_sqm": item.get("time_per_sqm").cloned().unwrap_or(Value::Null),
        "amount": item.get("amount").cloned().unwrap_or(Value::Null),
        "amount_unit": item.get("amount_unit").cloned().unwrap_or(Value::Null),
        "source": item.get("source").cloned().unwrap_or(Value::Null),
        "master": item.get("agricultural_task").cloned().unwrap_or(Value::Null),
        "actual": {
            "date": item.get("actual_date").cloned().unwrap_or(Value::Null),
            "notes": item.get("actual_notes").cloned().unwrap_or(Value::Null),
        },
        "history": {
            "rescheduled_at": item.get("rescheduled_at").cloned().unwrap_or(Value::Null),
            "cancelled_at": item.get("cancelled_at").cloned().unwrap_or(Value::Null),
            "completed_at": item.get("completed_at").cloned().unwrap_or(Value::Null),
        },
    })
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
