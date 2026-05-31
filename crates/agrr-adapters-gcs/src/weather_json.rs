use serde_json::Value;
use std::collections::BTreeMap;
use std::path::PathBuf;
use thiserror::Error;

const PREFIX: &str = "weather_data";

#[derive(Debug, Clone)]
pub struct WeatherDataGcsConfig {
    pub bucket: String,
    pub use_http: bool,
    pub local_root: Option<PathBuf>,
}

impl WeatherDataGcsConfig {
    pub fn from_env() -> Result<Self, WeatherDataGcsError> {
        let bucket = std::env::var("GCS_WEATHER_DATA_BUCKET")
            .or_else(|_| std::env::var("GCS_BUCKET"))
            .map_err(|_| WeatherDataGcsError::MissingBucket)?;
        let storage = std::env::var("WEATHER_DATA_STORAGE").unwrap_or_else(|_| "active_record".into());
        let use_http = storage == "gcs";
        let local_root = std::env::var("WEATHER_DATA_LOCAL_ROOT")
            .ok()
            .map(PathBuf::from);
        Ok(Self {
            bucket,
            use_http,
            local_root,
        })
    }
}

#[derive(Debug, Error)]
pub enum WeatherDataGcsError {
    #[error("GCS_WEATHER_DATA_BUCKET or GCS_BUCKET must be set")]
    MissingBucket,
    #[error("GCS authentication failed")]
    AuthFailed,
    #[error("GCS HTTP {status}: {message}")]
    HttpStatus { status: u16, message: String },
    #[error("HTTP error: {0}")]
    Http(#[from] reqwest::Error),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("JSON error: {0}")]
    Json(#[from] serde_json::Error),
}

pub struct WeatherDataGcsReader {
    config: WeatherDataGcsConfig,
    http: reqwest::Client,
}

impl WeatherDataGcsReader {
    pub fn new(config: WeatherDataGcsConfig) -> Self {
        Self {
            config,
            http: reqwest::Client::new(),
        }
    }

    pub fn object_key(weather_location_id: i64, year: i32) -> String {
        format!("{PREFIX}/{weather_location_id}/{year}.json")
    }

    pub async fn read_year_file(
        &self,
        weather_location_id: i64,
        year: i32,
    ) -> Result<WeatherYearFile, WeatherDataGcsError> {
        let key = Self::object_key(weather_location_id, year);
        let bytes: Vec<u8> = if self.config.use_http {
            let url = format!(
                "https://storage.googleapis.com/{}/{}",
                self.config.bucket, key
            );
            self.http
                .get(url)
                .send()
                .await?
                .error_for_status()?
                .bytes()
                .await?
                .to_vec()
        } else if let Some(root) = &self.config.local_root {
            let path = root.join(&key);
            tokio::fs::read(path).await?
        } else {
            return Ok(WeatherYearFile(BTreeMap::new()));
        };
        let map: BTreeMap<String, Value> = serde_json::from_slice(&bytes)?;
        Ok(WeatherYearFile(map))
    }
}

#[derive(Debug, Clone, Default)]
pub struct WeatherYearFile(pub BTreeMap<String, Value>);

impl WeatherYearFile {
    pub fn len(&self) -> usize {
        self.0.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use tempfile::tempdir;

    #[tokio::test]
    async fn reads_local_year_file_when_not_gcs() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsReader::object_key(7, 2024);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        let mut file = std::fs::File::create(&path).unwrap();
        writeln!(
            file,
            r#"{{"2024-01-01": {{"temperature_max": 10.0}}}}"#
        )
        .unwrap();
        let reader = WeatherDataGcsReader::new(WeatherDataGcsConfig {
            bucket: "test-bucket".into(),
            use_http: false,
            local_root: Some(dir.path().to_path_buf()),
        });
        let year = reader.read_year_file(7, 2024).await.unwrap();
        assert_eq!(year.len(), 1);
    }
}
