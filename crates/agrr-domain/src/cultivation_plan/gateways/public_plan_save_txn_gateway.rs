//! Transaction boundary for public plan save.

pub trait PublicPlanSaveTxnGateway: Send + Sync {
    fn within_transaction<F, T>(&self, block: F) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
    where
        F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>;
}
