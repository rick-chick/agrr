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
