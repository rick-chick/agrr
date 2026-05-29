//! Ruby: `Domain::Shared::Mappers::ReferencableListRowMapper`

use crate::shared::dtos::ReferencableListRow;

pub fn map_records<U, R, I>(user: &U, records: I) -> Vec<ReferencableListRow<R>>
where
    I: IntoIterator<Item = R>,
{
    records
        .into_iter()
        .map(|record| map_record(user, record))
        .collect()
}

pub fn map_record<U, R>(_user: &U, record: R) -> ReferencableListRow<R> {
    ReferencableListRow::new(record)
}

#[cfg(test)]
mod mappers_referencable_list_row_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/mappers_referencable_list_row_mapper_test.rs"));
}
