//! Ruby: `Adapters::Shared::Concerns::ReferenceIndexListFilterRelation`

use agrr_domain::shared::value_objects::reference_index_list_filter::{
    ReferenceIndexListFilter, ReferenceIndexListMode,
};

/// Dynamic WHERE fragment and bind parameters for org-scoped reference index listing.
pub struct ReferenceIndexWhereClause {
    pub sql: String,
    pub params: Vec<i64>,
}

fn org_in_clause(org_ids: &[i64], start_index: usize) -> (String, Vec<i64>) {
    if org_ids.is_empty() {
        return (String::new(), vec![]);
    }
    let placeholders: Vec<String> = (start_index..start_index + org_ids.len())
        .map(|i| format!("?{i}"))
        .collect();
    (
        format!("organization_id IN ({})", placeholders.join(", ")),
        org_ids.to_vec(),
    )
}

pub fn where_clause(filter: &ReferenceIndexListFilter) -> ReferenceIndexWhereClause {
    let org_ids = &filter.organization_ids;
    match filter.mode {
        ReferenceIndexListMode::ReferenceOrOwned => {
            if org_ids.is_empty() {
                ReferenceIndexWhereClause {
                    sql: "(is_reference = 1 OR user_id = ?1)".into(),
                    params: vec![filter.user_id],
                }
            } else {
                let (org_sql, mut params) = org_in_clause(org_ids, 1);
                let user_param_index = params.len() + 1;
                params.push(filter.user_id);
                ReferenceIndexWhereClause {
                    sql: format!(
                        "(is_reference = 1 OR {org_sql} OR (organization_id IS NULL AND user_id = ?{user_param_index}))"
                    ),
                    params,
                }
            }
        }
        ReferenceIndexListMode::OwnedNonReference => {
            if org_ids.is_empty() {
                ReferenceIndexWhereClause {
                    sql: "(user_id = ?1 AND is_reference = 0)".into(),
                    params: vec![filter.user_id],
                }
            } else {
                let (org_sql, mut params) = org_in_clause(org_ids, 1);
                let user_param_index = params.len() + 1;
                params.push(filter.user_id);
                ReferenceIndexWhereClause {
                    sql: format!(
                        "(({org_sql} OR (organization_id IS NULL AND user_id = ?{user_param_index})) AND is_reference = 0)"
                    ),
                    params,
                }
            }
        }
    }
}

/// Backward-compatible helper for gateways that only need a single user_id bind.
pub fn where_clause_legacy_user_id(filter: &ReferenceIndexListFilter) -> (&'static str, i64) {
    match filter.mode {
        ReferenceIndexListMode::ReferenceOrOwned => {
            ("(is_reference = 1 OR user_id = ?1)", filter.user_id)
        }
        ReferenceIndexListMode::OwnedNonReference => {
            ("(user_id = ?1 AND is_reference = 0)", filter.user_id)
        }
    }
}
