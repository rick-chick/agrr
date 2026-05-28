/// Ruby: `Domain::Shared::Dtos::ReferenceFlagChangeDeniedFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReferenceFlagChangeDeniedFailure {
    pub message: String,
    pub resource_id: i64,
}

impl ReferenceFlagChangeDeniedFailure {
    pub fn new(message: impl Into<String>, resource_id: i64) -> Self {
        Self {
            message: message.into(),
            resource_id,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exposes_message_and_resource_id() {
        let dto = ReferenceFlagChangeDeniedFailure::new("admin only", 42);
        assert_eq!(dto.message, "admin only");
        assert_eq!(dto.resource_id, 42);
    }
}
