//! Temp JSON files for agrr CLI (requires `.json` extension).

use std::io::Write;

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

pub fn path_string(file: &NamedTempFile) -> String {
    file.path().to_string_lossy().into_owned()
}

/// Write JSON to a persisted path with the handle closed (for agrr `--*-file` / `--output` args).
pub fn write_temp_json_path(data: &Value, prefix: &str) -> Result<std::path::PathBuf, std::io::Error> {
    let file = write_temp_json(data, prefix)?;
    let (handle, path) = file.keep()?;
    drop(handle);
    Ok(path)
}
