// Tests for `mappers/locale_to_region_mapper.rs` (Ruby parity under test/domain/shared/).


    #[test]
    fn maps_known_locales() {
        assert_eq!(locale_to_region("ja"), "jp");
        assert_eq!(locale_to_region("us"), "us");
        assert_eq!(locale_to_region("in"), "in");
    }

    #[test]
    fn defaults_unknown_locale_to_jp() {
        assert_eq!(locale_to_region("unknown"), "jp");
    }
