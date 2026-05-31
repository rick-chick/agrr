use std::path::PathBuf;

#[test]
fn streams_top_level_farm_entries_from_tiny_fixture() {
    let root = std::env::current_dir()
        .unwrap()
        .ancestors()
        .find(|p| p.join("crates/agrr-migrate").is_dir())
        .unwrap()
        .to_path_buf();
    let path: PathBuf = root.join("crates/agrr-migrate/tests/fixtures/tiny_weather.json");

    let mut keys = Vec::new();
    agrr_migrate::data::weather_stream::for_each_top_level_object_entry(&path, |key, value| {
        keys.push(key.to_string());
        assert!(value.contains("\"weather_data\""));
        Ok(())
    })
    .expect("stream parse");

    assert_eq!(vec!["TestFarm".to_string()], keys);
}
