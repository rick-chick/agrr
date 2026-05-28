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
mod tests {
    use super::*;

    #[derive(Debug, Clone, PartialEq, Eq)]
    struct StubRecord {
        id: i64,
    }

    #[test]
    fn map_record_wraps_record() {
        let record = StubRecord { id: 1 };
        let row = map_record(&(), record.clone());
        assert_eq!(row.record, record);
    }

    #[test]
    fn map_records_wraps_each_record() {
        let records = vec![StubRecord { id: 1 }, StubRecord { id: 2 }];
        let rows = map_records(&(), records.clone());
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].record, records[0]);
        assert_eq!(rows[1].record, records[1]);
    }
}
