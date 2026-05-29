// Tests for `calculators/planning_date_calculator.rs` (Ruby parity under test/domain/cultivation_plan/).

    use std::cell::RefCell;

    struct MockLogger {
        debug: RefCell<Vec<String>>,
        info: RefCell<Vec<String>>,
    }

    impl PlanningDateLogger for MockLogger {
        fn info(&self, message: &str) {
            self.info.borrow_mut().push(message.to_string());
        }
        fn debug(&self, message: &str) {
            self.debug.borrow_mut().push(message.to_string());
        }
    }

    // Ruby: test "normalize_decimal returns string F format for numeric"
    #[test]
    fn normalize_decimal_returns_string_f_format() {
        assert_eq!(
            normalize_decimal(Some(Decimal::new(15, 1))),
            Some("1.5".into())
        );
    }

    // Ruby: test "calculate_plan_year_from_cultivations uses midpoint years from periods"
    #[test]
    fn calculate_plan_year_from_cultivations_uses_midpoint_years() {
        let logger = MockLogger {
            debug: RefCell::new(vec![]),
            info: RefCell::new(vec![]),
        };
        let periods = vec![CultivationPeriod {
            start_date: date_ymd(2024, 6, 1),
            completion_date: date_ymd(2024, 8, 31),
        }];
        let year = calculate_plan_year_from_cultivations(
            &periods,
            &logger,
            date_ymd(2025, 1, 1),
        );
        assert_eq!(year, 2024);
        assert_eq!(logger.debug.borrow().len(), 3);
    }

    // Ruby: test "calculate_planning_dates_from_cultivations returns default window when periods empty"
    #[test]
    fn calculate_planning_dates_from_cultivations_default_window_when_empty() {
        let logger = MockLogger {
            debug: RefCell::new(vec![]),
            info: RefCell::new(vec![]),
        };
        let as_of = date_ymd(2025, 3, 15);
        let dates = calculate_planning_dates_from_cultivations(&[], &logger, as_of);
        assert_eq!(dates.start_date, date_ymd(2025, 1, 1));
        assert_eq!(dates.end_date, date_ymd(2026, 12, 31));
        assert_eq!(logger.info.borrow().len(), 1);
    }
