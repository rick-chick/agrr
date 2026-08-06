//! Unit tests for org-scoped reference index WHERE clause building.

use super::reference_index::where_clause;
use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

#[test]
fn reference_or_owned_without_org_ids_uses_user_id_fallback() {
    let filter = ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 7, vec![]);
    let clause = where_clause(&filter);
    assert_eq!("(is_reference = 1 OR user_id = ?1)", clause.sql);
    assert_eq!(vec![7], clause.params);
}

#[test]
fn reference_or_owned_with_org_ids_includes_org_and_legacy_user_rows() {
    let filter =
        ReferenceIndexListFilter::new(ReferenceIndexListMode::ReferenceOrOwned, 7, vec![10, 20]);
    let clause = where_clause(&filter);
    assert_eq!(
        "(is_reference = 1 OR organization_id IN (?1, ?2) OR (organization_id IS NULL AND user_id = ?3))",
        clause.sql
    );
    assert_eq!(vec![10, 20, 7], clause.params);
}

#[test]
fn owned_non_reference_without_org_ids_filters_by_user() {
    let filter =
        ReferenceIndexListFilter::new(ReferenceIndexListMode::OwnedNonReference, 3, vec![]);
    let clause = where_clause(&filter);
    assert_eq!("(user_id = ?1 AND is_reference = 0)", clause.sql);
    assert_eq!(vec![3], clause.params);
}

#[test]
fn owned_non_reference_with_org_ids_includes_org_and_legacy_user_rows() {
    let filter =
        ReferenceIndexListFilter::new(ReferenceIndexListMode::OwnedNonReference, 3, vec![5]);
    let clause = where_clause(&filter);
    assert_eq!(
        "((organization_id IN (?1) OR (organization_id IS NULL AND user_id = ?2)) AND is_reference = 0)",
        clause.sql
    );
    assert_eq!(vec![5, 3], clause.params);
}
