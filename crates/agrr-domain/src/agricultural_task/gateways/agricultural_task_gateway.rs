use crate::agricultural_task::dtos::AgriculturalTaskShowDetail;
use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::shared::attr::AttrMap;
use crate::shared::dtos::Error;
use crate::shared::user::User;

/// Ruby: `Domain::AgriculturalTask::Gateways::AgriculturalTaskGateway`
pub trait AgriculturalTaskGateway: Send + Sync {
    fn list_user_owned_tasks(
        &self,
        user_id: i64,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_reference_tasks(
        &self,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_user_and_reference_tasks(
        &self,
        user_id: i64,
        query: Option<&str>,
    ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_agricultural_task_show_detail(
        &self,
        id: i64,
    ) -> Result<AgriculturalTaskShowDetail, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_id(
        &self,
        id: i64,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_reference_and_name(
        &self,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_user_id_and_name(
        &self,
        user_id: i64,
        name: &str,
    ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>;

    fn create(
        &self,
        attrs: AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn update(
        &self,
        id: i64,
        attrs: AttrMap,
    ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>>;

    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T;

    fn soft_delete_with_undo(
        &self,
        user: &User,
        task_id: i64,
        auto_hide_after: i64,
        toast_message: &str,
    ) -> Result<SoftDeleteUndoResult, Box<dyn std::error::Error + Send + Sync>>;
}

#[derive(Debug, Clone)]
pub enum SoftDeleteUndoResult {
    Success { undo: crate::agricultural_task::dtos::UndoEntity },
    Failure { error: Error },
}
