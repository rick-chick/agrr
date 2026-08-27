use std::fs;
use std::path::{Path, PathBuf};

fn repo_root() -> PathBuf {
    std::env::current_dir()
        .unwrap()
        .ancestors()
        .find(|p| p.join("Cargo.toml").exists() && p.join("crates/agrr-migrate").is_dir())
        .expect("repo root from test cwd")
        .to_path_buf()
}

fn fixtures_dir() -> PathBuf {
    repo_root().join("crates/agrr-migrate/tests/fixtures")
}

fn assert_fixture_is_real_json(path: &Path) {
    let content = fs::read_to_string(path)
        .unwrap_or_else(|e| panic!("read {}: {e}", path.display()));
    assert!(
        !content.starts_with("version https://git-lfs"),
        "{} must be checked in as real JSON, not a Git LFS pointer (CI uses lfs: false)",
        path.display()
    );
    let trimmed = content.trim_start();
    assert!(
        trimmed.starts_with('{'),
        "{} must be a JSON object fixture",
        path.display()
    );
}

#[test]
fn agrr_migrate_test_fixtures_are_not_lfs_pointers() {
    let dir = fixtures_dir();
    let mut paths: Vec<PathBuf> = fs::read_dir(&dir)
        .unwrap_or_else(|e| panic!("read dir {}: {e}", dir.display()))
        .filter_map(|e| e.ok().map(|e| e.path()))
        .filter(|p| p.extension().is_some_and(|ext| ext == "json"))
        .collect();
    paths.sort();
    assert!(
        paths.len() >= 4,
        "expected at least 4 JSON fixtures under {}",
        dir.display()
    );
    for path in paths {
        assert_fixture_is_real_json(&path);
    }
}
