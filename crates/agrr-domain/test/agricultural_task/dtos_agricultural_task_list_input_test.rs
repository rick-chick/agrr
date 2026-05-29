// Tests for `dtos/agricultural_task_list_input.rs` (Ruby parity under test/domain/agricultural_task/).


    // Ruby: test "non-admin with any param normalizes to user"
    #[test]
    fn non_admin_normalizes_to_user() {
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("reference"), None).filter,
            "user"
        );
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("all"), None).filter,
            "user"
        );
        assert_eq!(
            AgriculturalTaskListInput::new(false, Some("bogus"), None).filter,
            "user"
        );
    }

    // Ruby: test "admin with nil normalizes to all"
    #[test]
    fn admin_nil_normalizes_to_all() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, None, None).filter,
            "all"
        );
    }

    // Ruby: test "admin with reference keeps reference"
    #[test]
    fn admin_reference_keeps_reference() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("reference"), None).filter,
            "reference"
        );
    }

    // Ruby: test "admin with invalid normalizes to all"
    #[test]
    fn admin_invalid_normalizes_to_all() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("bogus"), None).filter,
            "all"
        );
    }

    // Ruby: test "admin with user keeps user"
    #[test]
    fn admin_user_keeps_user() {
        assert_eq!(
            AgriculturalTaskListInput::new(true, Some("user"), None).filter,
            "user"
        );
    }
