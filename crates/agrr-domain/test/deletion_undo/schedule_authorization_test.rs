// Tests for `schedule_authorization.rs` (Ruby parity under test/domain/deletion_undo/).

    use crate::shared::user::User;

    // Ruby: test "schedule_allowed? permits crop owner to schedule crop deletion"
    #[test]
    fn schedule_allowed_permits_crop_owner_to_schedule_crop_deletion() {
        let user = User::new(1, false);
        let record = SchedulableRecord::crop(1, false);
        assert!(schedule_allowed(&user, &record));
    }

    // Ruby: test "schedule_allowed? denies other user on non-reference crop"
    #[test]
    fn schedule_allowed_denies_other_user_on_non_reference_crop() {
        let user = User::new(1, false);
        let record = SchedulableRecord::crop(99, false);
        assert!(!schedule_allowed(&user, &record));
    }
