use crate::user_account::dtos::UserDataExport;

/// Ruby: `Domain::UserAccount::Gateways::UserAccountGateway`
pub trait UserAccountGateway: Send + Sync {
    fn export_data(
        &self,
        user_id: i64,
    ) -> Result<UserDataExport, Box<dyn std::error::Error + Send + Sync>>;

    fn list_photo_storage_keys(
        &self,
        user_id: i64,
    ) -> Result<Vec<String>, Box<dyn std::error::Error + Send + Sync>>;

    fn delete_account(
        &self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn user_email(
        &self,
        user_id: i64,
    ) -> Result<Option<String>, Box<dyn std::error::Error + Send + Sync>>;
}
