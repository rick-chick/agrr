//! Loads `config/locales/**/*.yml` into flat translation keys (Rails I18n style).

use std::collections::HashMap;
use std::path::{Path, PathBuf};

use saphyr::{LoadableYamlNode, ScalarOwned, YamlOwned};

#[derive(Clone)]
pub struct LocaleCatalog {
    /// `ja` | `en` | `in` → `pests.undo.toast` → message template
    messages: HashMap<String, HashMap<String, String>>,
}

impl LocaleCatalog {
    pub fn load_from_dir(dir: &Path) -> Result<Self, String> {
        let mut messages: HashMap<String, HashMap<String, String>> = HashMap::new();
        load_dir_recursive(dir, &mut messages)?;
        Ok(Self { messages })
    }

    pub fn translate(&self, locale: &str, key: &str) -> Option<String> {
        let locale = normalize_locale(locale);
        self.messages
            .get(locale)
            .and_then(|m| m.get(key))
            .cloned()
            .or_else(|| {
                self.messages
                    .get("ja")
                    .and_then(|m| m.get(key))
                    .cloned()
            })
    }

    #[cfg(test)]
    pub fn from_pairs(locale: &str, pairs: &[(&str, &str)]) -> Self {
        let mut map = HashMap::new();
        for (k, v) in pairs {
            map.insert((*k).to_string(), (*v).to_string());
        }
        let mut messages = HashMap::new();
        messages.insert(locale.to_string(), map);
        Self { messages }
    }
}

pub fn normalize_locale(locale: &str) -> &str {
    match locale.split(',').next().unwrap_or(locale).trim().split('-').next() {
        Some("us") => "en",
        Some("ja") => "ja",
        Some("en") => "en",
        Some("in") => "in",
        Some("hi") => "in",
        _ => "ja",
    }
}

pub fn locales_dir_from_env() -> PathBuf {
    std::env::var("AGRR_LOCALES_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("config/locales"))
}

fn load_dir_recursive(dir: &Path, out: &mut HashMap<String, HashMap<String, String>>) -> Result<(), String> {
    let entries = std::fs::read_dir(dir).map_err(|e| format!("read_dir {}: {e}", dir.display()))?;
    for entry in entries {
        let entry = entry.map_err(|e| e.to_string())?;
        let path = entry.path();
        if path.is_dir() {
            load_dir_recursive(&path, out)?;
        } else if path.extension().and_then(|s| s.to_str()) == Some("yml") {
            merge_yaml_file(&path, out)?;
        }
    }
    Ok(())
}

fn merge_yaml_file(
    path: &Path,
    out: &mut HashMap<String, HashMap<String, String>>,
) -> Result<(), String> {
    let text = std::fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))?;
    // Rails locale files may repeat keys in one file; Psych last-wins. serde_yaml rejects them.
    let docs = YamlOwned::load_from_str(&text).map_err(|e| format!("yaml {}: {e}", path.display()))?;
    let Some(root) = docs.into_iter().next() else {
        return Ok(());
    };
    let YamlOwned::Mapping(mapping) = root else {
        return Ok(());
    };
    for (locale_key, content) in mapping {
        let Some(locale_str) = yaml_mapping_key(&locale_key) else {
            continue;
        };
        let catalog_locale = normalize_locale(&locale_str).to_string();
        let bucket = out.entry(catalog_locale).or_default();
        flatten_yaml_owned("", &content, bucket);
    }
    Ok(())
}

fn yaml_mapping_key(key: &YamlOwned) -> Option<String> {
    match key {
        YamlOwned::Value(ScalarOwned::String(s)) => Some(s.clone()),
        YamlOwned::Representation(rep, _, _) => Some(rep.clone()),
        _ => None,
    }
}

fn flatten_yaml_owned(prefix: &str, value: &YamlOwned, out: &mut HashMap<String, String>) {
    match value {
        YamlOwned::Mapping(map) => {
            for (k, v) in map {
                let Some(part) = yaml_mapping_key(&k) else {
                    continue;
                };
                let key = if prefix.is_empty() {
                    part
                } else {
                    format!("{prefix}.{part}")
                };
                flatten_yaml_owned(&key, v, out);
            }
        }
        YamlOwned::Value(ScalarOwned::String(s)) => {
            if !prefix.is_empty() {
                out.insert(prefix.to_string(), s.clone());
            }
        }
        YamlOwned::Representation(rep, _, _) => {
            if !prefix.is_empty() {
                out.insert(prefix.to_string(), rep.clone());
            }
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_locales_dir() -> PathBuf {
        let from_manifest = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../config/locales");
        if from_manifest.is_dir() {
            return from_manifest;
        }
        let from_env = locales_dir_from_env();
        assert!(
            from_env.is_dir(),
            "locales dir not found (tried {} and {})",
            from_manifest.display(),
            from_env.display()
        );
        from_env
    }

    #[test]
    fn loads_pests_undo_toast_from_repo_locales() {
        let dir = locales_dir_from_env();
        if !dir.is_dir() {
            return;
        }
        let catalog = LocaleCatalog::load_from_dir(&dir).expect("load locales");
        let msg = catalog
            .translate("in", "pests.undo.toast")
            .unwrap_or_default();
        assert!(
            msg.contains("हटाया"),
            "expected Hindi pests.undo.toast, got: {msg}"
        );
    }

    #[test]
    fn translate_falls_back_to_ja() {
        let catalog = LocaleCatalog::from_pairs("ja", &[("pests.undo.toast", "JA %{name}")]);
        assert_eq!(
            catalog.translate("in", "pests.undo.toast").as_deref(),
            Some("JA %{name}")
        );
    }

    #[test]
    fn loads_all_repo_locale_files() {
        let dir = locales_dir_from_env();
        if !dir.is_dir() {
            return;
        }
        LocaleCatalog::load_from_dir(&dir).expect("load all locale yaml files");
    }

    #[test]
    fn translates_api_errors_no_cultivation_period_from_repo_locales() {
        let dir = locales_dir_from_env();
        if !dir.is_dir() {
            return;
        }
        let catalog = LocaleCatalog::load_from_dir(&dir).expect("load locales");
        let expected = [
            ("ja", "栽培期間が設定されていません"),
            ("en", "Cultivation period is not set"),
        ];
        for (locale, want) in expected {
            let msg = catalog
                .translate(locale, "api.errors.no_cultivation_period")
                .unwrap_or_default();
            assert_eq!(
                msg, want,
                "locale={locale} api.errors.no_cultivation_period"
            );
        }
    }

    #[test]
    fn normalize_locale_maps_supported_and_fallback_tags() {
        assert_eq!(normalize_locale("ja"), "ja");
        assert_eq!(normalize_locale("ja-JP"), "ja");
        assert_eq!(normalize_locale("en"), "en");
        assert_eq!(normalize_locale("en-US"), "en");
        assert_eq!(normalize_locale("us"), "en");
        assert_eq!(normalize_locale("in"), "in");
        assert_eq!(normalize_locale("hi"), "in");
        assert_eq!(normalize_locale("hi-IN"), "in");
        assert_eq!(normalize_locale("fr"), "ja");
        assert_eq!(normalize_locale("  en, ja;q=0.9  "), "en");
    }

    const ENTRY_SCHEDULE_API_KEYS: &[&str] = &[
        "api.entry_schedule.label.sowing",
        "api.entry_schedule.label.transplanting",
        "api.entry_schedule.phase.label.sowing",
        "api.entry_schedule.phase.label.nursery",
        "api.entry_schedule.phase.label.transplant",
        "api.entry_schedule.phase.label.harvest",
        "api.entry_schedule.phase.empty.ineligible",
        "api.entry_schedule.phase.empty.no_sowing_window",
        "api.entry_schedule.phase.empty.no_transplant_window",
        "api.entry_schedule.phase.empty.nursery_gap",
        "api.entry_schedule.phase.empty.no_weather_end",
        "api.entry_schedule.flow.summary",
        "api.entry_schedule.flow.summary_fallback",
        "api.entry_schedule.flow.detail_chunk",
        "api.entry_schedule.flow.month_range",
        "api.entry_schedule.timeline.month_summary",
        "api.entry_schedule.disclaimer.short",
        "api.entry_schedule.reason.list",
        "api.entry_schedule.reason.agrr",
        "api.entry_schedule.reason.agrr_failed.generic",
        "api.entry_schedule.reason.agrr_failed.daemon_unavailable",
        "api.entry_schedule.reason.agrr_failed.execution_failed",
        "api.entry_schedule.reason.agrr_failed.invalid_response",
        "api.entry_schedule.reason.agrr_failed.insufficient_weather",
        "api.entry_schedule.reason.agrr_failed.disabled",
        "api.entry_schedule.reason.agrr_failed.crop_requirement_error",
        "api.entry_schedule.errors.weather_location_required",
        "api.entry_schedule.errors.prediction_failed",
    ];

    #[test]
    fn translates_entry_schedule_disclaimer_from_repo_locales() {
        let dir = locales_dir_from_env();
        if !dir.is_dir() {
            return;
        }
        let catalog = LocaleCatalog::load_from_dir(&dir).expect("load locales");
        let msg = catalog
            .translate("ja", "api.entry_schedule.disclaimer.short")
            .unwrap_or_default();
        assert!(
            !msg.is_empty() && !msg.starts_with("api."),
            "expected translated disclaimer, got: {msg}"
        );
    }

    #[test]
    fn translates_entry_schedule_api_keys_for_ja_en_and_in_from_repo_locales() {
        let dir = test_locales_dir();
        let catalog = LocaleCatalog::load_from_dir(&dir).expect("load locales");
        for key in ENTRY_SCHEDULE_API_KEYS {
            for locale in ["ja", "en", "in"] {
                let msg = catalog.translate(locale, key).unwrap_or_default();
                assert!(
                    !msg.is_empty() && !msg.starts_with("api."),
                    "locale={locale} key={key} got: {msg}"
                );
            }
        }
        let ja_disclaimer = catalog
            .translate("ja", "api.entry_schedule.disclaimer.short")
            .unwrap_or_default();
        assert!(
            ja_disclaimer.chars().any(|c| {
                ('\u{3040}'..='\u{309F}').contains(&c)
                    || ('\u{30A0}'..='\u{30FF}').contains(&c)
                    || ('\u{4E00}'..='\u{9FFF}').contains(&c)
            }),
            "expected Japanese entry_schedule disclaimer for ja locale, got: {ja_disclaimer}"
        );
        let in_disclaimer = catalog
            .translate("in", "api.entry_schedule.disclaimer.short")
            .unwrap_or_default();
        assert!(
            in_disclaimer.contains('य'),
            "expected Hindi entry_schedule disclaimer for in locale, got: {in_disclaimer}"
        );
    }
}
