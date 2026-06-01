use agrr_migrate::manifest::LegacyManifest;

#[test]
fn legacy_manifest_loads_primary_entries() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .parent()
        .unwrap();
    let m = LegacyManifest::load(root).expect("load manifest");
    assert_eq!(m.primary.len(), 123);
    assert!(
        m.primary.iter().any(|e| e.kind.as_deref() == Some("pests") && e.region == "jp"),
        "expected jp pests entry"
    );
}
