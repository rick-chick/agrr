//! Rails vs Rust migration parity via scripts/compare_rails_rust_migration_parity.rb (sqlite3 .schema / .dump diff).

use std::process::Command;

fn repo_root() -> std::path::PathBuf {
    std::env::current_dir()
        .unwrap()
        .ancestors()
        .find(|p| p.join("crates/agrr-migrate").is_dir())
        .expect("repo root")
        .to_path_buf()
}

#[test]
fn rails_and_rust_schema_match() {
    let root = repo_root();
    let script = root.join("scripts/compare_rails_rust_migration_parity.rb");
    let output = Command::new("bundle")
        .current_dir(&root)
        .args(["exec", "ruby", script.to_str().unwrap(), "--schema-only"])
        .output()
        .expect("spawn parity script --schema-only");

    assert!(
        output.status.success(),
        "schema parity failed:\n{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

#[test]
#[ignore = "loads full weather JSON via migrate_archive + agrr-migrate; run manually"]
fn rails_and_rust_reference_data_match() {
    let root = repo_root();
    let script = root.join("scripts/compare_rails_rust_migration_parity.rb");
    let output = Command::new("bundle")
        .current_dir(&root)
        .args(["exec", "ruby", script.to_str().unwrap()])
        .output()
        .expect("spawn parity script");

    assert!(
        output.status.success(),
        "reference data parity failed:\n{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}
