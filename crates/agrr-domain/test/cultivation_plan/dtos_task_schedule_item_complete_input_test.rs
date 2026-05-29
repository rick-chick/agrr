// Tests for `dtos/task_schedule_item_complete_input.rs` (Ruby parity under test/domain/cultivation_plan/).

    use time::macros::{date, datetime};

    struct FakeClock {
        today_val: Date,
        now_val: OffsetDateTime,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            self.today_val
        }

        fn now(&self) -> OffsetDateTime {
            self.now_val
        }
    }

    // Ruby: test "actual_date が空なら clock.today を使う"
    #[test]
    fn actual_date_defaults_to_clock_today_when_empty() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let dto =
            TaskScheduleItemCompleteInput::from_completion_params(&BTreeMap::new(), &clock)
                .unwrap();
        assert_eq!(dto.actual_date, date!(2026-03-01));
        assert_eq!(dto.completed_at, datetime!(2026-03-01 12:00 UTC));
    }

    // Ruby: test "実施日が Date のときそのまま使う"
    #[test]
    fn actual_date_uses_provided_iso_date_string() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let mut params = BTreeMap::new();
        params.insert(
            "actual_date".into(),
            Value::String("2026-04-10".into()),
        );
        let dto =
            TaskScheduleItemCompleteInput::from_completion_params(&params, &clock).unwrap();
        assert_eq!(dto.actual_date, date!(2026-04-10));
    }

    // Ruby: test "不正な日付文字列は RecordInvalid"
    #[test]
    fn invalid_date_string_returns_record_invalid() {
        let clock = FakeClock {
            today_val: date!(2026-03-01),
            now_val: datetime!(2026-03-01 12:00 UTC),
        };
        let mut params = BTreeMap::new();
        params.insert("actual_date".into(), Value::String("bogus".into()));
        let err =
            TaskScheduleItemCompleteInput::from_completion_params(&params, &clock).unwrap_err();
        assert!(!err.errors.as_ref().unwrap().get("actual_date").is_empty());
    }
