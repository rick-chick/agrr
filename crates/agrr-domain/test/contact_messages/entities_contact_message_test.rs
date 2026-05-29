// Tests for `entities/contact_message.rs` (Ruby parity under test/domain/contact_messages/).

    use time::macros::datetime;

    // Ruby: test "initializes with provided attributes and status helpers"
    #[test]
    fn initializes_with_provided_attributes_and_status_helpers() {
        let now = datetime!(2026-01-01 0:00 UTC);
        let entity = ContactMessage::new(ContactMessageAttrs {
            id: Some(1),
            name: Some("Taro".into()),
            email: Some("taro@example.com".into()),
            subject: Some("Hello".into()),
            message: Some("Hi there".into()),
            status: Some("sent".into()),
            created_at: Some(now),
            sent_at: Some(now),
            ..Default::default()
        });

        assert_eq!(entity.id, Some(1));
        assert_eq!(entity.name.as_deref(), Some("Taro"));
        assert_eq!(entity.email.as_deref(), Some("taro@example.com"));
        assert!(entity.sent());
        assert!(!entity.failed());
        assert!(!entity.queued());
    }

    // Ruby: test "requires email and message to be present"
    #[test]
    fn requires_email_and_message_to_be_present() {
        let entity = ContactMessage::new(ContactMessageAttrs {
            email: Some(String::new()),
            message: Some(String::new()),
            ..Default::default()
        });

        assert!(!entity.valid());
        assert!(!entity.validate().get("email").is_empty());
        assert!(!entity.validate().get("message").is_empty());
    }

    // Ruby: test "enforces length limits for optional fields"
    #[test]
    fn enforces_length_limits_for_optional_fields() {
        let mut entity = ContactMessage::new(ContactMessageAttrs {
            email: Some("a@b.com".into()),
            message: Some("ok".into()),
            ..Default::default()
        });
        entity.name = Some("n".repeat(300));
        entity.subject = Some("s".repeat(300));

        assert!(!entity.valid());
        assert!(!entity.validate().get("name").is_empty());
        assert!(!entity.validate().get("subject").is_empty());
    }
