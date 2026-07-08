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

#[test]
fn streams_utf8_farm_names_without_mojibake() {
    let root = std::env::current_dir()
        .unwrap()
        .ancestors()
        .find(|p| p.join("crates/agrr-migrate").is_dir())
        .unwrap()
        .to_path_buf();
    let path: PathBuf = root.join("crates/agrr-migrate/tests/fixtures/utf8_weather.json");

    let mut keys = Vec::new();
    agrr_migrate::data::weather_stream::for_each_top_level_object_entry(&path, |key, _value| {
        keys.push(key.to_string());
        Ok(())
    })
    .expect("stream parse");

    assert_eq!(vec!["北海道".to_string()], keys);
    assert_eq!(keys[0].as_bytes(), [0xe5, 0x8c, 0x97, 0xe6, 0xb5, 0xb7, 0xe9, 0x81, 0x93]);
}
