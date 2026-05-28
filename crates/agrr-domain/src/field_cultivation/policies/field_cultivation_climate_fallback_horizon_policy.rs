use time::Date;

pub fn prediction_days(completion_date: Date, training_end_date: Date) -> i64 {
    (completion_date - training_end_date).whole_days()
}

pub fn use_prediction_branch(prediction_days: i64) -> bool {
    prediction_days > 0
}

#[cfg(test)]
mod tests {
    use super::*;
    use time::macros::date;

    #[test]
    fn prediction_days_is_inclusive_day_delta() {
        let completion = date!(2026 - 06 - 01);
        let training_end = date!(2026 - 01 - 01);
        assert_eq!(prediction_days(completion, training_end), 151);
    }

    #[test]
    fn use_prediction_branch_when_positive() {
        assert!(use_prediction_branch(1));
        assert!(!use_prediction_branch(0));
        assert!(!use_prediction_branch(-1));
    }
}
