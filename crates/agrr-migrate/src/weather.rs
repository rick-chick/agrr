//! GCS bulk weather metadata maintenance (`WEATHER_DATA_STORAGE=gcs`).

use agrr_adapters_gcs::preload_blocking_http_client;
use agrr_adapters_sqlite::pool::SqlitePool;
use agrr_adapters_sqlite::WeatherDataGatewayBundle;

use crate::config::DbPaths;

pub fn rebuild_bulk_metadata(
    paths: &DbPaths,
    location_id: Option<i64>,
    missing_only: bool,
) -> anyhow::Result<()> {
    let storage = std::env::var("WEATHER_DATA_STORAGE").unwrap_or_default();
    anyhow::ensure!(
        storage == "gcs",
        "weather rebuild-bulk-metadata requires WEATHER_DATA_STORAGE=gcs (got {storage:?})"
    );

    preload_blocking_http_client();

    let pool = SqlitePool::new(
        paths
            .primary
            .to_str()
            .ok_or_else(|| anyhow::anyhow!("primary DB path is not UTF-8"))?,
    );
    let bundle = WeatherDataGatewayBundle::resolve(pool)?;

    if let Some(id) = location_id {
        bundle
            .rebuild_bulk_metadata(id)
            .map_err(|e| anyhow::anyhow!("location {id}: {e}"))?;
        println!("rebuilt weather bulk metadata for location {id}");
        return Ok(());
    }

    if missing_only {
        let count = bundle
            .rebuild_missing_bulk_metadata()
            .map_err(|e| anyhow::anyhow!("{e}"))?;
        println!("rebuilt weather bulk metadata for {count} location(s) missing metadata");
        return Ok(());
    }

    anyhow::bail!("specify --location-id <id> or --missing-only")
}
