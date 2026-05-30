//! Temp JSON files for agrr CLI (requires `.json` extension).

use std::io::Write;
use std::path::{Path, PathBuf};

use serde_json::Value;
use tempfile::NamedTempFile;

pub fn write_temp_json(data: &Value, prefix: &str) -> Result<NamedTempFile, std::io::Error> {
    let mut file = tempfile::Builder::new()
        .prefix(prefix)
        .suffix(".json")
        .tempfile()?;
    Write::write_all(
        &mut file,
        serde_json::to_string(data)?.as_bytes(),
    )?;
    file.as_file().sync_all()?;
    Ok(file)
}

pub fn path_buf(file: &NamedTempFile) -> PathBuf {
    file.path().to_path_buf()
}

pub fn path_string(file: &NamedTempFile) -> String {
    file.path().to_string_lossy().into_owned()
}

pub fn read_json_file(path: &Path) -> Result<Value, String> {
    let text = std::fs::read_to_string(path).map_err(|e| e.to_string())?;
    serde_json::from_str(&text).map_err(|e| e.to_string())
}
