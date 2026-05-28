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
mod tests {
    use super::*;

    // Ruby: test "non-admin with any param normalizes to user"
    #[test]
    fn non_admin_normalizes_to_user() {
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("reference"), None).filter,
            "user"
        );
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("all"), None).filter,
            "user"
        );
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("bogus"), None).filter,
            "user"
        );
    }

    // Ruby: test "admin with nil normalizes to all"
    #[test]
    fn admin_nil_normalizes_to_all() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, None, None).filter,
            "all"
        );
    }

    // Ruby: test "admin with reference keeps reference"
    #[test]
    fn admin_reference_keeps_reference() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("reference"), None).filter,
            "reference"
        );
    }

    // Ruby: test "admin with invalid normalizes to all"
    #[test]
    fn admin_invalid_normalizes_to_all() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("bogus"), None).filter,
            "all"
        );
    }

    // Ruby: test "admin with user keeps user"
    #[test]
    fn admin_user_keeps_user() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("user"), None).filter,
            "user"
        );
    }
}
