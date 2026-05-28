//! Pure domain logic for AGRR (migrated from `lib/domain`).
//!
//! See `docs/migration/lib-domain-rust/`.

pub mod agricultural_task;
pub mod api_keys;
pub mod auth;
pub mod backdoor;
pub mod crop;
pub mod internal_jobs;
pub mod contact_messages;
pub mod cultivation_plan;
pub mod deletion_undo;
pub mod farm;
pub mod field;
pub mod field_cultivation;
pub mod fertilize;
pub mod file_blob;
pub mod interaction_rule;
pub mod pest;
pub mod pesticide;
pub mod public_plan;
pub mod shared;
pub mod weather_data;
