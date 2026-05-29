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
mod mappers_locale_to_region_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/mappers_locale_to_region_mapper_test.rs"));
}
