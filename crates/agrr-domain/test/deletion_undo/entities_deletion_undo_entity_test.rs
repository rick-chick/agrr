// Tests for `entities/deletion_undo_entity.rs` (Ruby parity under test/domain/deletion_undo/).

    use time::macros::datetime;

    fn sample_entity() -> DeletionUndoEntity {
        DeletionUndoEntity::new(
            "tok",
            datetime!(2026-05-01 12:00:00 UTC),
            "scheduled",
            BTreeMap::new(),
        )
    }

    // Ruby: test "expired? is true when now is after expires_at"
    #[test]
    fn expired_is_true_when_now_is_after_expires_at() {
        let entity = sample_entity();
        assert!(entity.expired(datetime!(2026-05-01 12:00:01 UTC)));
    }

    // Ruby: test "expired? is false when now equals expires_at"
    #[test]
    fn expired_is_false_when_now_equals_expires_at() {
        let entity = sample_entity();
        assert!(!entity.expired(datetime!(2026-05-01 12:00:00 UTC)));
    }

    // Ruby: test "expired? is false when now is before expires_at"
    #[test]
    fn expired_is_false_when_now_is_before_expires_at() {
        let entity = sample_entity();
        assert!(!entity.expired(datetime!(2026-05-01 11:59:59 UTC)));
    }
