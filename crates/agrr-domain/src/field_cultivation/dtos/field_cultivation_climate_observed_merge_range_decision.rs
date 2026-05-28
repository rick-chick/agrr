use time::Date;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FieldCultivationClimateObservedMergeRangeDecision {
    skip: bool,
    pub start_date: Option<Date>,
    pub end_date: Option<Date>,
}

impl FieldCultivationClimateObservedMergeRangeDecision {
    pub fn skip() -> Self {
        Self {
            skip: true,
            start_date: None,
            end_date: None,
        }
    }

    pub fn range(start_date: Date, end_date: Date) -> Self {
        Self {
            skip: false,
            start_date: Some(start_date),
            end_date: Some(end_date),
        }
    }

    pub fn skip_merge(&self) -> bool {
        self.skip
    }
}
