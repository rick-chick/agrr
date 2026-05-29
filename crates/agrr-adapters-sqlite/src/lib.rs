//! SQLite adapters for `agrr-domain` gateway traits.
//!
//! Implementations follow the Ruby P4 pattern: **JOIN preload + row mapping into domain DTOs** —
//! no thick snapshot assembly in the adapter (see `docs/gateway-domain-logic-migration.md` §P4).
//!
//! **P6 status**: reference implementation only — not wired to production URL map until R4 contract GREEN.

pub mod field_cultivation;

pub use field_cultivation::FieldCultivationClimateSourceSqliteGateway;
