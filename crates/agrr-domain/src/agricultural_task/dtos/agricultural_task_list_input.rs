/// Ruby: `Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput`
#[derive(Debug, Clone)]
pub struct AgriculturalTaskListInput {
    pub is_admin: bool,
    pub filter: String,
    pub query: Option<String>,
}

impl AgriculturalTaskListInput {
    pub fn new(is_admin: bool, filter: Option<&str>, query: Option<String>) -> Self {
        Self {
            is_admin,
            filter: normalize_list_filter(is_admin, filter),
            query,
        }
    }

    pub fn default_for_user() -> Self {
        Self::new(false, None, None)
    }
}

fn normalize_list_filter(is_admin: bool, raw_filter: Option<&str>) -> String {
    const ALLOWED: &[&str] = &["user", "reference", "all"];
    let filter = raw_filter
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string);
    if is_admin {
        if let Some(ref f) = filter {
            if ALLOWED.contains(&f.as_str()) {
                return f.clone();
            }
        }
        return "all".to_string();
    }
    "user".to_string()
}

#[cfg(test)]
mod dtos_agricultural_task_list_input_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/agricultural_task/dtos_agricultural_task_list_input_test.rs"));
}
