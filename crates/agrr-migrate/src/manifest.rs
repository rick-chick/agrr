use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Deserialize)]
pub struct LegacyManifest {
    pub primary: Vec<LegacyEntry>,
    pub cache: Vec<LegacyEntry>,
    pub cable: Vec<LegacyEntry>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct LegacyEntry {
    pub version: String,
    pub file: String,
    pub tag: String,
    pub region: String,
    pub kind: Option<String>,
    pub name: String,
    #[serde(default)]
    pub database: Option<String>,
}

impl LegacyManifest {
    pub fn load(app_root: &Path) -> anyhow::Result<Self> {
        let path = app_root.join("crates/agrr-migrate/manifest/legacy_versions.yaml");
        let text = std::fs::read_to_string(&path)
            .map_err(|e| anyhow::anyhow!("read {}: {e}", path.display()))?;
        Ok(serde_yaml::from_str(&text)?)
    }

    pub fn data_entries_for(&self, region: &str, kind: &str) -> Vec<&LegacyEntry> {
        self.primary
            .iter()
            .filter(|e| e.tag == "data" || e.tag == "mixed")
            .filter(|e| entry_matches_region(e, region))
            .filter(|e| e.kind.as_deref() == Some(kind))
            .collect()
    }

    pub fn all_data_versions(&self) -> Vec<&LegacyEntry> {
        self.primary
            .iter()
            .filter(|e| e.tag == "data" || e.tag == "mixed")
            .filter(|e| e.kind.is_some())
            .collect()
    }
}

fn entry_matches_region(entry: &LegacyEntry, region: &str) -> bool {
    if region == "all" {
        return true;
    }
    entry.region == region || entry.region == "all"
}

pub const DATA_KINDS: &[&str] = &[
    "base",
    "nutrients",
    "pests",
    "tasks",
    "templates",
    "dev_fixtures",
];

pub fn parse_regions(raw: &str) -> Vec<String> {
    if raw == "all" {
        return vec!["jp".into(), "in".into(), "us".into()];
    }
    raw.split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}

pub fn parse_kinds(raw: &str) -> Vec<String> {
    raw.split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .collect()
}
