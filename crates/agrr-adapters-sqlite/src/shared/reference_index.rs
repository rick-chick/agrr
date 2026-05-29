//! Ruby: `Adapters::Shared::Concerns::ReferenceIndexListFilterRelation`

use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

pub fn where_clause(filter: &ReferenceIndexListFilter) -> (&'static str, i64) {
    match filter.mode {
        ReferenceIndexListMode::ReferenceOrOwned => {
            ("(is_reference = 1 OR user_id = ?1)", filter.user_id)
        }
        ReferenceIndexListMode::OwnedNonReference => {
            ("(user_id = ?1 AND is_reference = 0)", filter.user_id)
        }
    }
}
