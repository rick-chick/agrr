//! Refresh SQLite bulk metadata from GCS year files (`WEATHER_DATA_STORAGE=gcs`).

use std::collections::{BTreeMap, BTreeSet};

use agrr_adapters_gcs::WeatherDataGcsBulkGateway;
use agrr_domain::weather_data::dtos::WeatherData;
use serde_json::Value;

use super::weather_bulk_metadata::{
    recompute_bounds, year_stats_from_year_file, WeatherBulkMetadata,
};
use super::weather_bulk_metadata_store::WeatherBulkMetadataStore;

pub(crate) fn rebuild_bulk_metadata_from_gcs(
    gcs: &WeatherDataGcsBulkGateway,
    store: &WeatherBulkMetadataStore,
    weather_location_id: i64,
) -> Result<(), String> {
    let years = gcs
        .list_years(weather_location_id)
        .map_err(|e| e.to_string())?;
    let year_files = read_year_files(gcs, weather_location_id, &years)?;
    let metadata = metadata_from_year_files(&year_files);
    store.save(weather_location_id, &metadata)
}

pub(crate) fn refresh_bulk_metadata_years(
    gcs: &WeatherDataGcsBulkGateway,
    store: &WeatherBulkMetadataStore,
    weather_location_id: i64,
    years: &[i32],
) -> Result<(), String> {
    if years.is_empty() {
        return Ok(());
    }
    let year_files = read_year_files(gcs, weather_location_id, years)?;
    let mut metadata = store
        .load(weather_location_id)?
        .unwrap_or_default();
    merge_year_files_into_metadata(&mut metadata, &year_files);
    store.save(weather_location_id, &metadata)
}

fn read_year_files(
    gcs: &WeatherDataGcsBulkGateway,
    weather_location_id: i64,
    years: &[i32],
) -> Result<BTreeMap<i32, BTreeMap<String, Value>>, String> {
    let mut year_files: BTreeMap<i32, BTreeMap<String, Value>> = BTreeMap::new();
    for &year in years {
        let entries = gcs
            .read_year_file(weather_location_id, year)
            .map_err(|e| e.to_string())?;
        if entries.is_empty() {
            continue;
        }
        year_files.insert(year, entries);
    }
    Ok(year_files)
}

fn metadata_from_year_files(
    year_files: &BTreeMap<i32, BTreeMap<String, Value>>,
) -> WeatherBulkMetadata {
    let mut metadata = WeatherBulkMetadata::default();
    merge_year_files_into_metadata(&mut metadata, year_files);
    metadata
}

pub(crate) fn refresh_bulk_metadata_after_upsert(
    gcs: &WeatherDataGcsBulkGateway,
    store: &WeatherBulkMetadataStore,
    weather_location_id: i64,
    weather_data_dtos: &[WeatherData],
) -> Result<(), String> {
    let years: Vec<i32> = weather_data_dtos
        .iter()
        .map(|dto| dto.date.year())
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect();
    refresh_bulk_metadata_years(gcs, store, weather_location_id, &years)
}

fn merge_year_files_into_metadata(
    metadata: &mut WeatherBulkMetadata,
    year_files: &BTreeMap<i32, BTreeMap<String, Value>>,
) {
    for (&year, entries) in year_files {
        let key = year.to_string();
        if let Some(stats) = year_stats_from_year_file(entries) {
            metadata.years.insert(key, stats);
        } else {
            metadata.years.remove(&key);
        }
    }
    recompute_bounds(metadata);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pool::SqlitePool;
    use crate::weather_data::gcs_weather_test_support::write_year_fixture;
    use agrr_adapters_gcs::{WeatherDataGcsBulkGateway, WeatherDataGcsConfig};
    use agrr_domain::weather_data::dtos::WeatherData;
    use std::path::Path;
    use time::Month;

    fn local_gcs_gateway(dir: &Path) -> WeatherDataGcsBulkGateway {
        WeatherDataGcsBulkGateway::new(WeatherDataGcsConfig {
            bucket: "test-bucket".into(),
            use_http: true,
            local_root: Some(dir.to_path_buf()),
        })
    }

    fn test_pool_with_location(location_id: i64) -> SqlitePool {
        let path = std::env::temp_dir().join(format!(
            "agrr_bulk_meta_gcs_sync_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let _ = std::fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_string_lossy());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE weather_locations (
                    id INTEGER PRIMARY KEY,
                    latitude REAL,
                    longitude REAL,
                    created_at TEXT NOT NULL DEFAULT '1970-01-01',
                    updated_at TEXT NOT NULL DEFAULT '1970-01-01',
                    bulk_earliest_date TEXT,
                    bulk_latest_date TEXT,
                    bulk_year_stats TEXT
                );",
            )?;
            conn.execute(
                "INSERT INTO weather_locations (id, latitude, longitude) VALUES (?1, 35.0, 139.0)",
                rusqlite::params![location_id],
            )?;
            Ok(())
        })
        .expect("schema");
        pool
    }

    #[test]
    fn rebuild_bulk_metadata_from_gcs_replaces_stale_years_not_in_gcs() {
        use crate::weather_data::weather_bulk_metadata::{WeatherBulkMetadata, WeatherYearStats};
        use std::collections::BTreeMap;

        let dir = tempfile::tempdir().unwrap();
        write_year_fixture(
            dir.path(),
            7,
            2024,
            r#"{"2024-01-01": {"temperature_max": 10.0, "temperature_min": 5.0}}"#,
        );
        let gcs = local_gcs_gateway(dir.path());
        let pool = test_pool_with_location(7);
        let store = WeatherBulkMetadataStore::new(pool);
        store
            .save(
                7,
                &WeatherBulkMetadata {
                    earliest_date: Some("2020-01-01".into()),
                    latest_date: Some("2020-12-31".into()),
                    years: BTreeMap::from([(
                        "2020".into(),
                        WeatherYearStats {
                            count: 1,
                            historical_count: 1,
                            first_date: "2020-01-01".into(),
                            last_date: "2020-12-31".into(),
                        },
                    )]),
                },
            )
            .expect("seed stale metadata");

        rebuild_bulk_metadata_from_gcs(&gcs, &store, 7).expect("rebuild");

        let metadata = store.load(7).expect("load").expect("some");
        assert!(!metadata.years.contains_key("2020"));
        assert!(metadata.years.contains_key("2024"));
    }

    #[test]
    fn refresh_bulk_metadata_after_upsert_updates_store_for_touched_year() {
        let dir = tempfile::tempdir().unwrap();
        let gcs = local_gcs_gateway(dir.path());
        let pool = test_pool_with_location(7);
        let store = WeatherBulkMetadataStore::new(pool);
        let dto = WeatherData::new(
            time::Date::from_calendar_date(2025, Month::March, 1).unwrap(),
            Some(12.0),
            Some(4.0),
            None,
            None,
            None,
            None,
            None,
        );
        gcs.upsert_weather_data(&[dto.clone()], 7).expect("upsert");
        refresh_bulk_metadata_after_upsert(&gcs, &store, 7, &[dto]).expect("refresh");
        let metadata = store.load(7).expect("load").expect("some");
        assert!(metadata.years.contains_key("2025"));
    }
}
