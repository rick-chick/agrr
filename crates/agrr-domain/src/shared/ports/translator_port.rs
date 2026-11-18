use std::collections::BTreeMap;

use time::Date;

/// Ruby: `translate` / `localize` keyword options (`**options`).
pub type TranslateOptions = BTreeMap<String, String>;

/// Substitutes `%{name}` placeholders in Rails I18n templates (does not load keys).
pub fn apply_translation_options(template: &str, options: &TranslateOptions) -> String {
    let mut out = template.to_string();
    for (name, value) in options {
        out = out.replace(&format!("%{{{name}}}"), value);
    }
    out
}

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

#[cfg(test)]
mod translator_port_apply_translation_options_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/shared/translator_port_apply_translation_options_test.rs"
    ));
}
