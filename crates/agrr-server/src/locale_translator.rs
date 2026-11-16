//! `TranslatorPort` backed by `LocaleCatalog` (replaces passthrough for user-visible strings).

use agrr_domain::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use time::Date;

use crate::locale_catalog::LocaleCatalog;

pub struct LocaleTranslator<'a> {
    catalog: &'a LocaleCatalog,
    locale: &'a str,
}

impl<'a> LocaleTranslator<'a> {
    pub fn new(catalog: &'a LocaleCatalog, locale: &'a str) -> Self {
        Self { catalog, locale }
    }
}

impl TranslatorPort for LocaleTranslator<'_> {
    fn translate(&self, key: &str, _options: &TranslateOptions) -> String {
        self.catalog
            .translate(self.locale, key)
            .unwrap_or_else(|| key.to_string())
    }

    fn localize(&self, date: Date, _format: Option<&str>, _options: &TranslateOptions) -> String {
        date.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::locale_catalog::LocaleCatalog;
    use agrr_domain::shared::ports::translator_port::TranslatorPort;
    use std::collections::BTreeMap;
    use time::Date;

    fn empty_options() -> TranslateOptions {
        BTreeMap::new()
    }

    #[test]
    fn translate_returns_catalog_string_for_locale() {
        let catalog = LocaleCatalog::from_pairs("en", &[("api.errors.forbidden", "Forbidden")]);
        let translator = LocaleTranslator::new(&catalog, "en");
        assert_eq!(
            translator.translate("api.errors.forbidden", &empty_options()),
            "Forbidden"
        );
    }

    #[test]
    fn translate_falls_back_to_key_when_missing() {
        let catalog = LocaleCatalog::from_pairs("en", &[("known.key", "Known")]);
        let translator = LocaleTranslator::new(&catalog, "en");
        assert_eq!(
            translator.translate("missing.key", &empty_options()),
            "missing.key"
        );
    }

    #[test]
    fn localize_formats_date_as_iso_string() {
        let catalog = LocaleCatalog::from_pairs("en", &[]);
        let translator = LocaleTranslator::new(&catalog, "en");
        let date = Date::from_calendar_date(2026, time::Month::June, 15).expect("valid date");
        assert_eq!(
            translator.localize(date, None, &empty_options()),
            "2026-06-15"
        );
    }
}
