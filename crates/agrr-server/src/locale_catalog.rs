//! Loads `config/locales/**/*.yml` into flat translation keys (Rails I18n style).

use std::collections::HashMap;
use std::path::{Path, PathBuf};

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
    let root: serde_yaml::Value =
        serde_yaml::from_str(&text).map_err(|e| format!("yaml {}: {e}", path.display()))?;
    let Some(mapping) = root.as_mapping() else {
        return Ok(());
    };
    for (locale_key, content) in mapping {
        let Some(locale_str) = locale_key.as_str() else {
            continue;
        };
        let catalog_locale = normalize_locale(locale_str).to_string();
        let bucket = out.entry(catalog_locale).or_default();
        flatten_value("", content, bucket);
    }
    Ok(())
}

fn flatten_value(prefix: &str, value: &serde_yaml::Value, out: &mut HashMap<String, String>) {
    match value {
        serde_yaml::Value::Mapping(map) => {
            for (k, v) in map {
                let Some(part) = k.as_str() else { continue };
                let key = if prefix.is_empty() {
                    part.to_string()
                } else {
                    format!("{prefix}.{part}")
                };
                flatten_value(&key, v, out);
            }
        }
        serde_yaml::Value::String(s) => {
            out.insert(prefix.to_string(), s.clone());
        }
        _ => {}
    }
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
