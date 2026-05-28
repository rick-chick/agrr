//! Ruby: `Domain::Shared::Mappers::LocaleToRegionMapper`

/// Map app locale to reference farm region code (`jp` / `us` / `in`).
pub fn locale_to_region(locale: impl AsRef<str>) -> &'static str {
    match locale.as_ref() {
        "ja" => "jp",
        "us" => "us",
        "in" => "in",
        _ => "jp",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
