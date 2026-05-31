//! Rails parity: `unless Rails.env.production?` → copy agrr CLI temp JSON under `tmp/debug`.

use std::path::{Path, PathBuf};

use serde_json::Value;

/// `AGRR_ENV` / `RAILS_ENV` (default `development`). Disabled when `production`.
pub fn daemon_debug_enabled() -> bool {
    let env = std::env::var("AGRR_ENV")
        .or_else(|_| std::env::var("RAILS_ENV"))
        .unwrap_or_else(|_| "development".into());
    env != "production"
}

/// Project root: `AGRR_ROOT` or current working directory (Rails `Rails.root` in compose).
pub fn project_root() -> PathBuf {
    std::env::var("AGRR_ROOT")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."))
        })
}

/// Copy `source` to `{root}/tmp/debug/{dest_basename}_{unix_ts}.json`.
pub fn copy_temp_file_to_debug(source: &Path, dest_basename: &str) {
    if !daemon_debug_enabled() {
        return;
    }
    let debug_dir = project_root().join("tmp/debug");
    if std::fs::create_dir_all(&debug_dir).is_err() {
        return;
    }
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let dest = debug_dir.join(format!("{dest_basename}_{ts}.json"));
    match std::fs::copy(source, &dest) {
        Ok(_) => eprintln!("📁 [AGRR] Debug {dest_basename} saved to: {}", dest.display()),
        Err(e) => eprintln!(
            "agrr debug: failed to copy {} -> {}: {e}",
            source.display(),
            dest.display()
        ),
    }
}

/// Write pretty JSON to `{root}/tmp/debug/{dest_basename}_{unix_ts}.json` (prediction output parity).
pub fn write_json_value_to_debug(dest_basename: &str, value: &Value) {
    if !daemon_debug_enabled() {
        return;
    }
    let debug_dir = project_root().join("tmp/debug");
    if std::fs::create_dir_all(&debug_dir).is_err() {
        return;
    }
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let dest = debug_dir.join(format!("{dest_basename}_{ts}.json"));
    match serde_json::to_string_pretty(value) {
        Ok(body) => {
            if std::fs::write(&dest, body).is_ok() {
                eprintln!("📁 [AGRR] Debug {dest_basename} saved to: {}", dest.display());
            }
        }
        Err(e) => eprintln!("agrr debug: failed to serialize {dest_basename}: {e}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::sync::Mutex;

    static ENV_TEST_LOCK: Mutex<()> = Mutex::new(());

    fn restore_env(key: &str, prev: Option<String>) {
        match prev {
            Some(v) => std::env::set_var(key, v),
            None => std::env::remove_var(key),
        }
    }

    #[test]
    fn copy_temp_file_to_debug_writes_under_tmp_debug_when_not_production() {
        let _guard = ENV_TEST_LOCK.lock().unwrap();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();
        let prev_root = std::env::var("AGRR_ROOT").ok();

        let root = tempfile::tempdir().expect("tempdir");
        std::env::set_var("AGRR_ROOT", root.path());
        std::env::set_var("AGRR_ENV", "development");
        std::env::remove_var("RAILS_ENV");

        let mut src = tempfile::NamedTempFile::new().expect("src");
        write!(src, r#"{{"k":1}}"#).expect("write");
        src.flush().expect("flush");

        copy_temp_file_to_debug(src.path(), "allocation_fields");

        let debug_dir = root.path().join("tmp/debug");
        let entries: Vec<_> = std::fs::read_dir(&debug_dir)
            .expect("debug dir")
            .filter_map(|e| e.ok())
            .collect();
        assert_eq!(entries.len(), 1);
        let name = entries[0].file_name().to_string_lossy().into_owned();
        assert!(
            name.starts_with("allocation_fields_") && name.ends_with(".json"),
            "unexpected name: {name}"
        );
        let body = std::fs::read_to_string(entries[0].path()).expect("read");
        assert!(body.contains("\"k\":1"));

        restore_env("AGRR_ENV", prev_env);
        restore_env("RAILS_ENV", prev_rails);
        restore_env("AGRR_ROOT", prev_root);
    }

    #[test]
    fn copy_temp_file_to_debug_skips_in_production() {
        let _guard = ENV_TEST_LOCK.lock().unwrap();
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_root = std::env::var("AGRR_ROOT").ok();

        let root = tempfile::tempdir().expect("tempdir");
        std::env::set_var("AGRR_ROOT", root.path());
        std::env::set_var("AGRR_ENV", "production");

        let mut src = tempfile::NamedTempFile::new().expect("src");
        write!(src, "{{}}").expect("write");
        copy_temp_file_to_debug(src.path(), "allocation_fields");

        assert!(!root.path().join("tmp/debug").exists());

        restore_env("AGRR_ENV", prev_env);
        restore_env("AGRR_ROOT", prev_root);
    }
}
