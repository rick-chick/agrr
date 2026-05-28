use std::collections::BTreeMap;

use time::Date;

/// Ruby: `translate` / `localize` keyword options (`**options`).
pub type TranslateOptions = BTreeMap<String, String>;

/// Ruby: `Domain::Shared::Ports::TranslatorPort`
pub trait TranslatorPort: Send + Sync {
    fn translate(&self, key: &str, options: &TranslateOptions) -> String;

    fn t(&self, key: &str, options: &TranslateOptions) -> String {
        self.translate(key, options)
    }

    fn localize(&self, date: Date, format: Option<&str>, options: &TranslateOptions) -> String;

    fn l(&self, date: Date, format: Option<&str>, options: &TranslateOptions) -> String {
        self.localize(date, format, options)
    }
}
