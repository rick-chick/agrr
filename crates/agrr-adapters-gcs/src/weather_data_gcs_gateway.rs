//! Sync GCS bulk weather store — Ruby: `WeatherDataGcsHttpGateway` (bulk I/O only).

use std::collections::BTreeMap;

use agrr_domain::weather_data::dtos::WeatherData;
use serde_json::{json, Value};
use time::Date;

use crate::gcs_object_client::GcsObjectClient;
use crate::weather_json::{WeatherDataGcsConfig, WeatherDataGcsError, WeatherDataGcsReader};

const PREFIX: &str = "weather_data";

pub struct WeatherDataGcsBulkGateway {
    client: GcsObjectClient,
}

impl WeatherDataGcsBulkGateway {
    pub fn new(config: WeatherDataGcsConfig) -> Self {
        Self {
            client: GcsObjectClient::new(config),
        }
    }

    pub fn from_env() -> Result<Self, WeatherDataGcsError> {
        Ok(Self::new(WeatherDataGcsConfig::from_env()?))
    }

    pub fn object_key(weather_location_id: i64, year: i32) -> String {
        WeatherDataGcsReader::object_key(weather_location_id, year)
    }

    pub fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataGcsError> {
        let mut dtos = Vec::new();
        for year in years_for_range(Some(start_date), Some(end_date)) {
            let data = self.read_year_file(weather_location_id, year)?;
            for (date_str, attrs) in &data {
                let Some(date) = parse_date(date_str) else {
                    continue;
                };
                if date < start_date || date > end_date {
                    continue;
                }
                dtos.push(hash_to_dto(date, attrs));
            }
        }
        dtos.sort_by_key(|d| d.date);
        Ok(dtos)
    }

    pub fn weather_data_count(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataGcsError> {
        Ok(self
            .weather_data_for_period_filtered(weather_location_id, start_date, end_date)?
            .len() as i64)
    }

    pub fn historical_data_count(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataGcsError> {
        Ok(self
            .weather_data_for_period(weather_location_id, start_date, end_date)?
            .iter()
            .filter(|d| d.temperature_max.is_some() && d.temperature_min.is_some())
            .count() as i64)
    }

    pub fn earliest_date(&self, weather_location_id: i64) -> Result<Option<Date>, WeatherDataGcsError> {
        self.min_max_date(weather_location_id, true)
    }

    pub fn latest_date(&self, weather_location_id: i64) -> Result<Option<Date>, WeatherDataGcsError> {
        self.min_max_date(weather_location_id, false)
    }

    pub fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), WeatherDataGcsError> {
        if weather_data_dtos.is_empty() {
            return Ok(());
        }
        let mut by_year: BTreeMap<i32, Vec<&WeatherData>> = BTreeMap::new();
        for dto in weather_data_dtos {
            by_year.entry(dto.date.year()).or_default().push(dto);
        }
        for (year, dtos) in by_year {
            let mut existing = self.read_year_file(weather_location_id, year)?;
            for dto in dtos {
                existing.insert(dto.date.to_string(), dto_to_value(dto));
            }
            self.write_year_file(weather_location_id, year, &existing)?;
        }
        Ok(())
    }

    fn weather_data_for_period_filtered(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<Vec<WeatherData>, WeatherDataGcsError> {
        match (start_date, end_date) {
            (Some(s), Some(e)) => self.weather_data_for_period(weather_location_id, s, e),
            (None, None) => self.all_weather_data(weather_location_id),
            (start, end) => {
                let years = years_for_range(start, end);
                let mut dtos = Vec::new();
                for year in years {
                    let data = self.read_year_file(weather_location_id, year)?;
                    for (date_str, attrs) in data {
                        let Some(date) = parse_date(&date_str) else {
                            continue;
                        };
                        if let Some(s) = start {
                            if date < s {
                                continue;
                            }
                        }
                        if let Some(e) = end {
                            if date > e {
                                continue;
                            }
                        }
                        dtos.push(hash_to_dto(date, &attrs));
                    }
                }
                dtos.sort_by_key(|d| d.date);
                Ok(dtos)
            }
        }
    }

    fn all_weather_data(
        &self,
        weather_location_id: i64,
    ) -> Result<Vec<WeatherData>, WeatherDataGcsError> {
        let mut dtos = Vec::new();
        for year in self.list_years(weather_location_id)? {
            let data = self.read_year_file(weather_location_id, year)?;
            for (date_str, attrs) in data {
                if let Some(date) = parse_date(&date_str) {
                    dtos.push(hash_to_dto(date, &attrs));
                }
            }
        }
        dtos.sort_by_key(|d| d.date);
        Ok(dtos)
    }

    fn min_max_date(
        &self,
        weather_location_id: i64,
        want_min: bool,
    ) -> Result<Option<Date>, WeatherDataGcsError> {
        let mut result: Option<Date> = None;
        for year in self.list_years(weather_location_id)? {
            let data = self.read_year_file(weather_location_id, year)?;
            for date_str in data.keys() {
                let Some(date) = parse_date(date_str) else {
                    continue;
                };
                result = Some(match result {
                    None => date,
                    Some(cur) if want_min && date < cur => date,
                    Some(cur) if !want_min && date > cur => date,
                    Some(cur) => cur,
                });
            }
        }
        Ok(result)
    }

    fn read_year_file(
        &self,
        weather_location_id: i64,
        year: i32,
    ) -> Result<BTreeMap<String, Value>, WeatherDataGcsError> {
        let key = Self::object_key(weather_location_id, year);
        let Some(bytes) = self.client.read_object(&key)? else {
            return Ok(BTreeMap::new());
        };
        parse_json_map(std::str::from_utf8(&bytes).unwrap_or(""))
    }

    fn write_year_file(
        &self,
        weather_location_id: i64,
        year: i32,
        data: &BTreeMap<String, Value>,
    ) -> Result<(), WeatherDataGcsError> {
        let key = Self::object_key(weather_location_id, year);
        let json_str = serde_json::to_string(data)?;
        self.client.write_object(&key, json_str.as_bytes())
    }

    fn list_years(&self, weather_location_id: i64) -> Result<Vec<i32>, WeatherDataGcsError> {
        let prefix = format!("{PREFIX}/{weather_location_id}/");
        let mut years = Vec::new();
        for name in self.client.list_object_names(&prefix)? {
            if let Some(file_name) = name.strip_prefix(&prefix) {
                if let Some(stem) = file_name.strip_suffix(".json") {
                    if let Ok(y) = stem.parse::<i32>() {
                        years.push(y);
                    }
                }
            }
        }
        years.sort_unstable();
        Ok(years)
    }
}

fn years_for_range(start_date: Option<Date>, end_date: Option<Date>) -> Vec<i32> {
    match (start_date, end_date) {
        (None, None) => vec![],
        (Some(s), Some(e)) => (s.year()..=e.year()).collect(),
        (Some(s), None) => vec![s.year()],
        (None, Some(e)) => vec![e.year()],
    }
}

fn parse_date(s: &str) -> Option<Date> {
    Date::parse(s.trim(), &time::format_description::well_known::Iso8601::DATE).ok()
}

fn parse_json_map(raw: &str) -> Result<BTreeMap<String, Value>, WeatherDataGcsError> {
    if raw.trim().is_empty() {
        return Ok(BTreeMap::new());
    }
    match serde_json::from_str::<BTreeMap<String, Value>>(raw) {
        Ok(m) => Ok(m),
        Err(e) => Err(WeatherDataGcsError::Json(e)),
    }
}

/// GCS year files store numerics as JSON numbers or strings (Rails `.to_json` parity).
fn json_value_as_f64(value: &Value) -> Option<f64> {
    match value {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn json_value_as_i32(value: &Value) -> Option<i32> {
    match value {
        Value::Number(n) => n.as_i64().and_then(|i| i32::try_from(i).ok()),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn hash_to_dto(date: Date, attrs: &Value) -> WeatherData {
    WeatherData::new(
        date,
        attrs.get("temperature_max").and_then(json_value_as_f64),
        attrs.get("temperature_min").and_then(json_value_as_f64),
        attrs.get("temperature_mean").and_then(json_value_as_f64),
        attrs.get("precipitation").and_then(json_value_as_f64),
        attrs.get("sunshine_hours").and_then(json_value_as_f64),
        attrs.get("wind_speed").and_then(json_value_as_f64),
        attrs.get("weather_code").and_then(json_value_as_i32),
    )
}

fn dto_to_value(dto: &WeatherData) -> Value {
    json!({
        "temperature_max": dto.temperature_max,
        "temperature_min": dto.temperature_min,
        "temperature_mean": dto.temperature_mean,
        "precipitation": dto.precipitation,
        "sunshine_hours": dto.sunshine_hours,
        "wind_speed": dto.wind_speed,
        "weather_code": dto.weather_code,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;
    use std::path::Path;
    use tempfile::tempdir;
    use time::Month;

    fn local_gateway(dir: &Path) -> WeatherDataGcsBulkGateway {
        WeatherDataGcsBulkGateway::new(WeatherDataGcsConfig {
            bucket: "test-bucket".into(),
            use_http: true,
            local_root: Some(dir.to_path_buf()),
        })
    }

    #[test]
    fn weather_data_for_period_returns_empty_when_no_data() {
        let dir = tempdir().unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = Date::from_calendar_date(2023, Month::January, 2).unwrap();
        let dtos = gw.weather_data_for_period(1, start, end).unwrap();
        assert!(dtos.is_empty());
    }

    #[test]
    fn weather_data_for_period_returns_dtos_from_local_files() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(1, 2023);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        let mut file = std::fs::File::create(&path).unwrap();
        writeln!(
            file,
            r#"{{"2023-01-01": {{"temperature_max": 10.0, "temperature_min": 5.0, "temperature_mean": 7.5, "precipitation": 0.0, "sunshine_hours": 6.0, "wind_speed": 3.0, "weather_code": 0}}, "2023-01-02": {{"temperature_max": 12.0, "temperature_min": 6.0, "temperature_mean": 9.0, "precipitation": 0.0, "sunshine_hours": 7.0, "wind_speed": 4.0, "weather_code": 1}}}}"#
        )
        .unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = Date::from_calendar_date(2023, Month::January, 2).unwrap();
        let dtos = gw.weather_data_for_period(1, start, end).unwrap();
        assert_eq!(dtos.len(), 2);
        assert_eq!(dtos[0].temperature_max, Some(10.0));
    }

    #[test]
    fn weather_data_for_period_parses_string_numeric_fields_from_gcs() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(6, 2024);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(
            path,
            r#"{"2024-01-01":{"temperature_max":"13.9","temperature_min":"4.3","temperature_mean":"8.5","precipitation":"0.0","sunshine_hours":"8.8","wind_speed":"6.6","weather_code":0}}"#,
        )
        .unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2024, Month::January, 1).unwrap();
        let end = start;
        let dtos = gw.weather_data_for_period(6, start, end).unwrap();
        assert_eq!(dtos.len(), 1);
        assert_eq!(dtos[0].temperature_max, Some(13.9));
        assert_eq!(dtos[0].temperature_min, Some(4.3));
        assert_eq!(gw.historical_data_count(6, start, end).unwrap(), 1);
    }

    #[test]
    fn weather_data_count_returns_correct_count() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(2, 2023);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, r#"{"2023-01-01": {}, "2023-01-02": {}}"#).unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = Date::from_calendar_date(2023, Month::January, 2).unwrap();
        assert_eq!(gw.weather_data_count(2, Some(start), Some(end)).unwrap(), 2);
    }

    #[test]
    fn upsert_writes_and_merges_year_file() {
        let dir = tempdir().unwrap();
        let gw = local_gateway(dir.path());
        let d1 = Date::from_calendar_date(2023, Month::January, 3).unwrap();
        let dto = WeatherData::new(d1, Some(15.0), Some(10.0), Some(12.5), None, None, None, None);
        gw.upsert_weather_data(&[dto], 3).unwrap();

        let start = Date::from_calendar_date(2023, Month::January, 3).unwrap();
        let end = start;
        let dtos = gw.weather_data_for_period(3, start, end).unwrap();
        assert_eq!(dtos.len(), 1);
        assert_eq!(dtos[0].temperature_max, Some(15.0));

        let d2 = Date::from_calendar_date(2023, Month::January, 2).unwrap();
        let dto2 = WeatherData::new(d2, Some(12.0), Some(6.0), Some(9.0), None, None, None, None);
        gw.upsert_weather_data(&[dto2], 3).unwrap();
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = Date::from_calendar_date(2023, Month::January, 3).unwrap();
        let merged = gw.weather_data_for_period(3, start, end).unwrap();
        assert_eq!(merged.len(), 2);
    }

    #[test]
    fn latest_and_earliest_date_scan_year_files() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(4, 2023);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, r#"{"2023-01-02": {}, "2023-01-01": {}}"#).unwrap();
        let gw = local_gateway(dir.path());
        let earliest = gw.earliest_date(4).unwrap();
        let latest = gw.latest_date(4).unwrap();
        assert_eq!(
            earliest,
            Some(Date::from_calendar_date(2023, Month::January, 1).unwrap())
        );
        assert_eq!(
            latest,
            Some(Date::from_calendar_date(2023, Month::January, 2).unwrap())
        );
    }

    #[test]
    fn historical_data_count_requires_temp_max_and_min() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(5, 2023);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(
            path,
            r#"{"2023-01-01": {"temperature_max": 10.0, "temperature_min": 5.0}, "2023-01-02": {"temperature_max": null, "temperature_min": 6.0}}"#,
        )
        .unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = Date::from_calendar_date(2023, Month::January, 2).unwrap();
        assert_eq!(
            gw.historical_data_count(5, start, end).unwrap(),
            1
        );
    }

    #[test]
    fn invalid_json_returns_error_not_empty_map() {
        let dir = tempdir().unwrap();
        let key = WeatherDataGcsBulkGateway::object_key(9, 2023);
        let path = dir.path().join(&key);
        std::fs::create_dir_all(path.parent().unwrap()).unwrap();
        std::fs::write(path, "not-json").unwrap();
        let gw = local_gateway(dir.path());
        let start = Date::from_calendar_date(2023, Month::January, 1).unwrap();
        let end = start;
        assert!(gw.weather_data_for_period(9, start, end).is_err());
    }
}
