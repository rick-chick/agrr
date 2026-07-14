//! GCS / local FS object store for work record photos.

use std::path::PathBuf;

use agrr_domain::work_record::gateways::WorkRecordPhotoObjectStoreGateway;

use crate::gcs_object_client::GcsObjectClient;
use crate::weather_json::{WeatherDataGcsConfig, WeatherDataGcsError};

pub struct WorkRecordPhotoGcsStore {
    client: GcsObjectClient,
}

impl WorkRecordPhotoGcsStore {
    pub fn from_env() -> Result<Self, WeatherDataGcsError> {
        let config = work_record_photo_config_from_env()?;
        Ok(Self {
            client: GcsObjectClient::new(config),
        })
    }

    pub fn with_local_root(root: PathBuf) -> Self {
        Self {
            client: GcsObjectClient::new(WeatherDataGcsConfig {
                bucket: "local".into(),
                use_http: false,
                local_root: Some(root),
            }),
        }
    }
}

fn work_record_photo_config_from_env() -> Result<WeatherDataGcsConfig, WeatherDataGcsError> {
    let storage =
        std::env::var("WORK_RECORD_PHOTO_STORAGE").unwrap_or_else(|_| "local".into());
    if storage == "gcs" {
        return WeatherDataGcsConfig::from_env();
    }
    let local_root = std::env::var("WORK_RECORD_PHOTO_LOCAL_ROOT")
        .ok()
        .map(PathBuf::from)
        .or_else(|| std::env::var("WEATHER_DATA_LOCAL_ROOT").ok().map(PathBuf::from))
        .or_else(|| Some(PathBuf::from("storage/work_record_photos")));
    Ok(WeatherDataGcsConfig {
        bucket: std::env::var("GCS_WORK_RECORD_PHOTO_BUCKET")
            .or_else(|_| std::env::var("GCS_BUCKET"))
            .unwrap_or_else(|_| "local".into()),
        use_http: false,
        local_root,
    })
}

impl WorkRecordPhotoObjectStoreGateway for WorkRecordPhotoGcsStore {
    fn write_object(
        &self,
        storage_key: &str,
        content_type: &str,
        bytes: &[u8],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.client
            .write_object_with_content_type(storage_key, content_type, bytes)?;
        Ok(())
    }

    fn read_object(
        &self,
        storage_key: &str,
    ) -> Result<Option<Vec<u8>>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.client.read_object(storage_key)?)
    }

    fn delete_object(
        &self,
        storage_key: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.client.delete_object(storage_key)?;
        Ok(())
    }
}
