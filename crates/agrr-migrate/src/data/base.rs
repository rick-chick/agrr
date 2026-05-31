use super::context::{self, ensure_anonymous_user, fixtures_dir, with_transaction};
use super::weather_stream;
use anyhow::Context;
use rusqlite::{params, Connection, Transaction};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::Path;

const WEATHER_BATCH: usize = 5000;

struct RegionFixtures<'a> {
    weather: &'a str,
    crops: &'a str,
}

fn region_fixtures(region: &str) -> anyhow::Result<RegionFixtures<'static>> {
    Ok(match region {
        "jp" => RegionFixtures {
            weather: "reference_weather.json",
            crops: "reference_crops.json",
        },
        "us" => RegionFixtures {
            weather: "us_reference_weather.json",
            crops: "us_reference_crops.json",
        },
        "in" => RegionFixtures {
            weather: "india_reference_weather.json",
            crops: "india_reference_crops.json",
        },
        other => anyhow::bail!("unknown region for base: {other}"),
    })
}

pub fn apply(conn: &mut Connection, app_root: &Path, region: &str) -> anyhow::Result<()> {
    let paths = region_fixtures(region)?;
    let anonymous_id = if region == "jp" {
        seed_japan_admin_user(conn)?
    } else {
        ensure_anonymous_user(conn)?
    };
    let skip_weather = std::env::var("AGRR_MIGRATE_SKIP_WEATHER").is_ok();
    let weather_path = fixtures_dir(app_root).join(paths.weather);
    if skip_weather {
        if weather_path.is_file() {
            seed_farms_without_weather_data(conn, region, anonymous_id, &weather_path)?;
        } else {
            println!("  ⚠ weather fixture missing: {}", weather_path.display());
            seed_basic_farms(conn, region, anonymous_id)?;
        }
    } else if weather_path.is_file() {
        seed_farms_and_weather(conn, region, anonymous_id, &weather_path)?;
    } else {
        println!("  ⚠ weather fixture missing: {}", weather_path.display());
        seed_basic_farms(conn, region, anonymous_id)?;
    }
    seed_crops(conn, app_root, region, paths.crops)?;
    if region == "jp" {
        seed_japan_sample_fields(conn)?;
    }
    seed_interaction_rules(conn, region)?;
    Ok(())
}

struct IndiaInlineCrop {
    name: &'static str,
    variety: &'static str,
    groups: &'static [&'static str],
    area_per_unit: f64,
    revenue_per_area: f64,
}

const INDIA_INLINE_CROPS: &[IndiaInlineCrop] = &[
    IndiaInlineCrop { name: "चावल", variety: "बासमती", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "चावल", variety: "IR64", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 7000.0 },
    IndiaInlineCrop { name: "गेहूं", variety: "HD2967", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 6000.0 },
    IndiaInlineCrop { name: "कपास", variety: "बीटी कपास", groups: &["Malvaceae"], area_per_unit: 0.25, revenue_per_area: 12000.0 },
    IndiaInlineCrop { name: "गन्ना", variety: "CoC671", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 15000.0 },
    IndiaInlineCrop { name: "सोयाबीन", variety: "JS335", groups: &["Fabaceae"], area_per_unit: 0.25, revenue_per_area: 7000.0 },
    IndiaInlineCrop { name: "मूंगफली", variety: "TMV2", groups: &["Fabaceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "चना", variety: "देसी", groups: &["Fabaceae"], area_per_unit: 0.25, revenue_per_area: 9000.0 },
    IndiaInlineCrop { name: "मसूर", variety: "मसूर दाल", groups: &["Fabaceae"], area_per_unit: 0.25, revenue_per_area: 8500.0 },
    IndiaInlineCrop { name: "अरहर", variety: "तूर दाल", groups: &["Fabaceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "मक्का", variety: "संकर", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 7000.0 },
    IndiaInlineCrop { name: "बाजरा", variety: "मोती बाजरा", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 5000.0 },
    IndiaInlineCrop { name: "ज्वार", variety: "ज्वार अनाज", groups: &["Poaceae"], area_per_unit: 0.25, revenue_per_area: 5000.0 },
    IndiaInlineCrop { name: "सरसों", variety: "पूसा बोल्ड", groups: &["Brassicaceae"], area_per_unit: 0.25, revenue_per_area: 7000.0 },
    IndiaInlineCrop { name: "सूरजमुखी", variety: "KBSH44", groups: &["Asteraceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "जूट", variety: "JRO524", groups: &["Malvaceae"], area_per_unit: 0.25, revenue_per_area: 6000.0 },
    IndiaInlineCrop { name: "मिर्च", variety: "गुंटूर", groups: &["Solanaceae"], area_per_unit: 0.25, revenue_per_area: 15000.0 },
    IndiaInlineCrop { name: "टमाटर", variety: "पूसा रूबी", groups: &["Solanaceae"], area_per_unit: 0.25, revenue_per_area: 12000.0 },
    IndiaInlineCrop { name: "आलू", variety: "कुफरी", groups: &["Solanaceae"], area_per_unit: 0.25, revenue_per_area: 10000.0 },
    IndiaInlineCrop { name: "प्याज", variety: "नासिक लाल", groups: &["Amaryllidaceae"], area_per_unit: 0.25, revenue_per_area: 9000.0 },
    IndiaInlineCrop { name: "बैंगन", variety: "बैंगन", groups: &["Solanaceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "पत्ता गोभी", variety: "गोल्डन एकर", groups: &["Brassicaceae"], area_per_unit: 0.25, revenue_per_area: 7000.0 },
    IndiaInlineCrop { name: "फूल गोभी", variety: "स्नोबॉल", groups: &["Brassicaceae"], area_per_unit: 0.25, revenue_per_area: 8000.0 },
    IndiaInlineCrop { name: "चाय", variety: "असम", groups: &["Theaceae"], area_per_unit: 0.25, revenue_per_area: 20000.0 },
    IndiaInlineCrop { name: "कॉफी", variety: "अरेबिका", groups: &["Rubiaceae"], area_per_unit: 0.25, revenue_per_area: 25000.0 },
    IndiaInlineCrop { name: "हल्दी", variety: "अल्लेप्पी", groups: &["Zingiberaceae"], area_per_unit: 0.25, revenue_per_area: 18000.0 },
    IndiaInlineCrop { name: "अदरक", variety: "रियो", groups: &["Zingiberaceae"], area_per_unit: 0.25, revenue_per_area: 16000.0 },
    IndiaInlineCrop { name: "इलायची", variety: "मालाबार", groups: &["Zingiberaceae"], area_per_unit: 0.25, revenue_per_area: 30000.0 },
    IndiaInlineCrop { name: "नारियल", variety: "लंबा", groups: &["Arecaceae"], area_per_unit: 0.25, revenue_per_area: 12000.0 },
    IndiaInlineCrop { name: "आम", variety: "अल्फांसो", groups: &["Anacardiaceae"], area_per_unit: 0.25, revenue_per_area: 20000.0 },
];

#[derive(Debug, Deserialize)]
struct FarmWeatherFixture {
    latitude: serde_json::Value,
    longitude: serde_json::Value,
    weather_location: Option<WeatherLocationFixture>,
    weather_data: Option<Vec<WeatherDatumFixture>>,
}

#[derive(Debug, Deserialize)]
struct WeatherLocationFixture {
    latitude: serde_json::Value,
    longitude: serde_json::Value,
    elevation: Option<f64>,
    timezone: Option<String>,
}

#[derive(Debug, Deserialize)]
struct WeatherDatumFixture {
    date: String,
    temperature_max: Option<f64>,
    temperature_min: Option<f64>,
    temperature_mean: Option<f64>,
    precipitation: Option<f64>,
    sunshine_hours: Option<f64>,
    wind_speed: Option<f64>,
    weather_code: Option<i64>,
}

/// Loads every farm from the weather fixture (names + coordinates) without weather rows.
fn seed_farms_without_weather_data(
    conn: &mut Connection,
    region: &str,
    user_id: i64,
    weather_path: &Path,
) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    let mut farm_count = 0usize;

    weather_stream::for_each_top_level_object_entry(weather_path, |farm_name, value_json| {
        let farm_data: FarmWeatherFixture =
            serde_json::from_str(value_json).with_context(|| format!("parse farm {farm_name}"))?;
        let lat = json_f64(&farm_data.latitude)?;
        let lon = json_f64(&farm_data.longitude)?;

        with_transaction(conn, |tx| {
            upsert_farm(tx, farm_name, region, user_id, lat, lon, &now)?;
            Ok(())
        })?;

        farm_count += 1;
        Ok(())
    })?;

    println!("  base/{region}: {farm_count} reference farms (weather skipped)");
    Ok(())
}

fn seed_farms_and_weather(
    conn: &mut Connection,
    region: &str,
    user_id: i64,
    weather_path: &Path,
) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    let mut farm_count = 0usize;

    weather_stream::for_each_top_level_object_entry(weather_path, |farm_name, value_json| {
        let farm_data: FarmWeatherFixture =
            serde_json::from_str(value_json).with_context(|| format!("parse farm {farm_name}"))?;
        let lat = json_f64(&farm_data.latitude)?;
        let lon = json_f64(&farm_data.longitude)?;

        with_transaction(conn, |tx| {
            let farm_id = upsert_farm(tx, farm_name, region, user_id, lat, lon, &now)?;
            if let Some(wl_data) = &farm_data.weather_location {
                let wl_id = upsert_weather_location(tx, wl_data, &now)?;
                tx.execute(
                    "UPDATE farms SET weather_location_id = ?1, updated_at = ?2 WHERE id = ?3",
                    params![wl_id, now, farm_id],
                )?;
                if let Some(records) = &farm_data.weather_data {
                    upsert_weather_data_batch(tx, wl_id, records, &now)?;
                    tx.execute(
                        "UPDATE farms SET weather_data_status = 'completed', weather_data_fetched_years = 5,
                         weather_data_total_years = 5, updated_at = ?1 WHERE id = ?2",
                        params![now, farm_id],
                    )?;
                }
            }
            Ok(())
        })?;

        farm_count += 1;
        println!("  weather: loaded farm {farm_name}");
        Ok(())
    })?;

    println!("  base/{region}: {farm_count} reference farms with weather");
    Ok(())
}

fn json_f64(v: &serde_json::Value) -> anyhow::Result<f64> {
    match v {
        serde_json::Value::Number(n) => n
            .as_f64()
            .ok_or_else(|| anyhow::anyhow!("invalid number")),
        serde_json::Value::String(s) => s.parse().context("parse float string"),
        _ => anyhow::bail!("expected number or string"),
    }
}

fn upsert_farm(
    tx: &Transaction<'_>,
    name: &str,
    region: &str,
    user_id: i64,
    lat: f64,
    lon: f64,
    now: &str,
) -> anyhow::Result<i64> {
    if let Ok(id) = tx.query_row(
        "SELECT id FROM farms WHERE name = ?1 AND is_reference = 1 AND region = ?2",
        params![name, region],
        |r| r.get(0),
    ) {
        tx.execute(
            "UPDATE farms SET user_id = ?1, latitude = ?2, longitude = ?3, updated_at = ?4 WHERE id = ?5",
            params![user_id, lat, lon, now, id],
        )?;
        return Ok(id);
    }
    tx.execute(
        "INSERT INTO farms (name, latitude, longitude, is_reference, user_id, region, created_at, updated_at)
         VALUES (?1, ?2, ?3, 1, ?4, ?5, ?6, ?6)",
        params![name, lat, lon, user_id, region, now],
    )?;
    Ok(tx.last_insert_rowid())
}

fn upsert_weather_location(
    tx: &Transaction<'_>,
    wl: &WeatherLocationFixture,
    now: &str,
) -> anyhow::Result<i64> {
    let lat = json_f64(&wl.latitude)?;
    let lon = json_f64(&wl.longitude)?;
    if let Ok(id) = tx.query_row(
        "SELECT id FROM weather_locations WHERE latitude = ?1 AND longitude = ?2",
        params![lat, lon],
        |r| r.get(0),
    ) {
        tx.execute(
            "UPDATE weather_locations SET elevation = COALESCE(?1, elevation), timezone = COALESCE(?2, timezone),
             updated_at = ?3 WHERE id = ?4",
            params![wl.elevation, wl.timezone, now, id],
        )?;
        return Ok(id);
    }
    tx.execute(
        "INSERT INTO weather_locations (latitude, longitude, elevation, timezone, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5, ?5)",
        params![lat, lon, wl.elevation, wl.timezone, now],
    )?;
    Ok(tx.last_insert_rowid())
}

fn upsert_weather_data_batch(
    tx: &Transaction<'_>,
    weather_location_id: i64,
    records: &[WeatherDatumFixture],
    now: &str,
) -> anyhow::Result<()> {
    for chunk in records.chunks(WEATHER_BATCH) {
        for wd in chunk {
            tx.execute(
                "INSERT INTO weather_data (weather_location_id, date, temperature_max, temperature_min, temperature_mean,
                 precipitation, sunshine_hours, wind_speed, weather_code, created_at, updated_at)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?10)
                 ON CONFLICT(weather_location_id, date) DO UPDATE SET
                   temperature_max = excluded.temperature_max,
                   temperature_min = excluded.temperature_min,
                   temperature_mean = excluded.temperature_mean,
                   precipitation = excluded.precipitation,
                   sunshine_hours = excluded.sunshine_hours,
                   wind_speed = excluded.wind_speed,
                   weather_code = excluded.weather_code,
                   updated_at = excluded.updated_at",
                params![
                    weather_location_id,
                    wd.date,
                    wd.temperature_max,
                    wd.temperature_min,
                    wd.temperature_mean,
                    wd.precipitation,
                    wd.sunshine_hours,
                    wd.wind_speed,
                    wd.weather_code,
                    now
                ],
            )?;
        }
    }
    Ok(())
}

fn seed_basic_farms(conn: &mut Connection, region: &str, user_id: i64) -> anyhow::Result<()> {
    let farms: &[(&str, f64, f64)] = match region {
        "jp" => &[
            ("北海道", 43.0642, 141.3469),
            ("東京", 35.6762, 139.6503),
        ],
        "us" => &[("Kansas", 38.5266, -96.7265)],
        "in" => &[("Punjab", 30.9010, 75.8573)],
        _ => &[],
    };
    let now = context::now_rfc3339();
    with_transaction(conn, |tx| {
        for (name, lat, lon) in farms {
            upsert_farm(tx, name, region, user_id, *lat, *lon, &now)?;
        }
        Ok(())
    })?;
    Ok(())
}

#[derive(Debug, Deserialize)]
struct CropFixture {
    variety: String,
    area_per_unit: f64,
    revenue_per_area: f64,
    groups: Option<Vec<String>>,
    crop_stages: Vec<CropStageFixture>,
}

#[derive(Debug, Deserialize)]
struct CropStageFixture {
    name: String,
    order: i64,
    temperature_requirement: Option<TempReqFixture>,
    sunshine_requirement: Option<SunReqFixture>,
    thermal_requirement: Option<ThermalFixture>,
}

#[derive(Debug, Deserialize)]
struct TempReqFixture {
    base_temperature: Option<f64>,
    optimal_min: Option<f64>,
    optimal_max: Option<f64>,
    low_stress_threshold: Option<f64>,
    high_stress_threshold: Option<f64>,
    frost_threshold: Option<f64>,
    sterility_risk_threshold: Option<f64>,
    max_temperature: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct SunReqFixture {
    minimum_sunshine_hours: Option<f64>,
    target_sunshine_hours: Option<f64>,
}

#[derive(Debug, Deserialize)]
struct ThermalFixture {
    required_gdd: Option<f64>,
}

fn seed_crops(conn: &mut Connection, app_root: &Path, region: &str, crops_file: &str) -> anyhow::Result<()> {
    let path = fixtures_dir(app_root).join(crops_file);
    if region == "in" && !path.is_file() {
        println!("  ⚠ crops fixture missing: {}; using inline India crops", path.display());
        return seed_india_inline_crops(conn);
    }
    let text = std::fs::read_to_string(&path)
        .with_context(|| format!("read crops fixture {}", path.display()))?;
    let crop_map: HashMap<String, CropFixture> = serde_json::from_str(&text)?;
    let now = context::now_rfc3339();

    with_transaction(conn, |tx| {
        for (crop_name, crop_data) in &crop_map {
            let groups_json = serde_json::to_string(&crop_data.groups.clone().unwrap_or_default())?;
            let crop_id = upsert_crop(
                tx,
                crop_name,
                &crop_data.variety,
                region,
                crop_data.area_per_unit,
                crop_data.revenue_per_area,
                &groups_json,
                &now,
            )?;
            for stage in &crop_data.crop_stages {
                let stage_id = upsert_crop_stage(tx, crop_id, &stage.name, stage.order, &now)?;
                if let Some(tr) = &stage.temperature_requirement {
                    upsert_temperature_requirement(tx, stage_id, tr, &now)?;
                }
                if let Some(sr) = &stage.sunshine_requirement {
                    upsert_sunshine_requirement(tx, stage_id, sr, &now)?;
                }
                if let Some(th) = &stage.thermal_requirement {
                    upsert_thermal_requirement(tx, stage_id, th, &now)?;
                }
            }
        }
        Ok(())
    })?;

    println!(
        "  base/{region}: {} reference crops from {}",
        crop_map.len(),
        crops_file
    );
    Ok(())
}

fn upsert_crop(
    tx: &Transaction<'_>,
    name: &str,
    variety: &str,
    region: &str,
    area_per_unit: f64,
    revenue_per_area: f64,
    groups_json: &str,
    now: &str,
) -> anyhow::Result<i64> {
    if let Ok(id) = tx.query_row(
        "SELECT id FROM crops WHERE name = ?1 AND variety = ?2 AND is_reference = 1 AND region = ?3",
        params![name, variety, region],
        |r| r.get(0),
    ) {
        tx.execute(
            "UPDATE crops SET groups = ?1, area_per_unit = ?2, revenue_per_area = ?3, updated_at = ?4 WHERE id = ?5",
            params![groups_json, area_per_unit, revenue_per_area, now, id],
        )?;
        return Ok(id);
    }
    tx.execute(
        "INSERT INTO crops (name, variety, is_reference, user_id, region, groups, area_per_unit, revenue_per_area, created_at, updated_at)
         VALUES (?1, ?2, 1, NULL, ?3, ?4, ?5, ?6, ?7, ?7)",
        params![name, variety, region, groups_json, area_per_unit, revenue_per_area, now],
    )?;
    Ok(tx.last_insert_rowid())
}

fn upsert_crop_stage(
    tx: &Transaction<'_>,
    crop_id: i64,
    name: &str,
    order: i64,
    now: &str,
) -> anyhow::Result<i64> {
    if let Ok(id) = tx.query_row(
        "SELECT id FROM crop_stages WHERE crop_id = ?1 AND \"order\" = ?2",
        params![crop_id, order],
        |r| r.get(0),
    ) {
        tx.execute(
            "UPDATE crop_stages SET name = ?1, updated_at = ?2 WHERE id = ?3",
            params![name, now, id],
        )?;
        return Ok(id);
    }
    tx.execute(
        "INSERT INTO crop_stages (crop_id, name, \"order\", created_at, updated_at) VALUES (?1, ?2, ?3, ?4, ?4)",
        params![crop_id, name, order, now],
    )?;
    Ok(tx.last_insert_rowid())
}

fn upsert_temperature_requirement(
    tx: &Transaction<'_>,
    stage_id: i64,
    tr: &TempReqFixture,
    now: &str,
) -> anyhow::Result<()> {
    let base_temperature = tr.base_temperature.unwrap_or(10.0);
    let optimal_min = tr.optimal_min.unwrap_or(18.0);
    let optimal_max = tr.optimal_max.unwrap_or(30.0);
    let low_stress_threshold = tr.low_stress_threshold.unwrap_or(10.0);
    let high_stress_threshold = tr.high_stress_threshold.unwrap_or(35.0);
    let frost_threshold = tr.frost_threshold.unwrap_or(0.0);
    let sterility_risk_threshold = tr.sterility_risk_threshold.unwrap_or(32.0);

    let n: i64 = tx.query_row(
        "SELECT COUNT(*) FROM temperature_requirements WHERE crop_stage_id = ?1",
        params![stage_id],
        |r| r.get(0),
    )?;
    if n > 0 {
        tx.execute(
            "UPDATE temperature_requirements SET base_temperature = ?1, optimal_min = ?2, optimal_max = ?3,
             low_stress_threshold = ?4, high_stress_threshold = ?5, frost_threshold = ?6,
             sterility_risk_threshold = ?7, max_temperature = ?8, updated_at = ?9
             WHERE crop_stage_id = ?10",
            params![
                base_temperature,
                optimal_min,
                optimal_max,
                low_stress_threshold,
                high_stress_threshold,
                frost_threshold,
                sterility_risk_threshold,
                tr.max_temperature,
                now,
                stage_id
            ],
        )?;
    } else {
        tx.execute(
            "INSERT INTO temperature_requirements (crop_stage_id, base_temperature, optimal_min, optimal_max,
             low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature,
             created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?10)",
            params![
                stage_id,
                base_temperature,
                optimal_min,
                optimal_max,
                low_stress_threshold,
                high_stress_threshold,
                frost_threshold,
                sterility_risk_threshold,
                tr.max_temperature,
                now
            ],
        )?;
    }
    Ok(())
}

fn upsert_sunshine_requirement(
    tx: &Transaction<'_>,
    stage_id: i64,
    sr: &SunReqFixture,
    now: &str,
) -> anyhow::Result<()> {
    let minimum_sunshine_hours = sr.minimum_sunshine_hours.unwrap_or(6.0);
    let target_sunshine_hours = sr.target_sunshine_hours.unwrap_or(8.0);
    let n: i64 = tx.query_row(
        "SELECT COUNT(*) FROM sunshine_requirements WHERE crop_stage_id = ?1",
        params![stage_id],
        |r| r.get(0),
    )?;
    if n > 0 {
        tx.execute(
            "UPDATE sunshine_requirements SET minimum_sunshine_hours = ?1, target_sunshine_hours = ?2, updated_at = ?3
             WHERE crop_stage_id = ?4",
            params![minimum_sunshine_hours, target_sunshine_hours, now, stage_id],
        )?;
    } else {
        tx.execute(
            "INSERT INTO sunshine_requirements (crop_stage_id, minimum_sunshine_hours, target_sunshine_hours, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?4)",
            params![stage_id, minimum_sunshine_hours, target_sunshine_hours, now],
        )?;
    }
    Ok(())
}

fn upsert_thermal_requirement(
    tx: &Transaction<'_>,
    stage_id: i64,
    th: &ThermalFixture,
    now: &str,
) -> anyhow::Result<()> {
    let required_gdd = th.required_gdd.unwrap_or(800.0);
    let n: i64 = tx.query_row(
        "SELECT COUNT(*) FROM thermal_requirements WHERE crop_stage_id = ?1",
        params![stage_id],
        |r| r.get(0),
    )?;
    if n > 0 {
        tx.execute(
            "UPDATE thermal_requirements SET required_gdd = ?1, updated_at = ?2 WHERE crop_stage_id = ?3",
            params![required_gdd, now, stage_id],
        )?;
    } else {
        tx.execute(
            "INSERT INTO thermal_requirements (crop_stage_id, required_gdd, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?3)",
            params![stage_id, required_gdd, now],
        )?;
    }
    Ok(())
}

fn seed_interaction_rules(conn: &mut Connection, region: &str) -> anyhow::Result<()> {
    let impacts = interaction_impacts(region);
    let now = context::now_rfc3339();

    let mut families: Vec<String> = {
        let mut stmt = conn.prepare(
            "SELECT groups FROM crops WHERE is_reference = 1 AND region = ?1",
        )?;
        let mut set = std::collections::BTreeSet::new();
        let rows = stmt.query_map(params![region], |r| r.get::<_, String>(0))?;
        for g in rows.flatten() {
            if let Ok(arr) = serde_json::from_str::<Vec<String>>(&g) {
                for f in arr {
                    set.insert(f);
                }
            }
        }
        set.into_iter().collect()
    };
    families.sort();

    with_transaction(conn, |tx| {
        for family in &families {
            let (ratio, desc) = impacts
                .get(family.as_str())
                .copied()
                .unwrap_or((0.8, "{family} continuous cultivation (default)"));
            let description = desc.to_string();
            if let Ok(id) = tx.query_row(
                "SELECT id FROM interaction_rules WHERE rule_type = 'continuous_cultivation' AND source_group = ?1
                 AND target_group = ?1 AND region = ?2 AND is_reference = 1",
                params![family, region],
                |r| r.get::<_, i64>(0),
            ) {
                tx.execute(
                    "UPDATE interaction_rules SET impact_ratio = ?1, description = ?2, updated_at = ?3 WHERE id = ?4",
                    params![ratio, description, now, id],
                )?;
            } else {
                tx.execute(
                    "INSERT INTO interaction_rules (rule_type, source_group, target_group, impact_ratio, is_directional,
                     is_reference, user_id, region, description, created_at, updated_at)
                     VALUES ('continuous_cultivation', ?1, ?1, ?2, 1, 1, NULL, ?3, ?4, ?5, ?5)",
                    params![family, ratio, region, description, now],
                )?;
            }
        }
        Ok(())
    })?;

    println!(
        "  base/{region}: {} interaction_rules from crop groups",
        families.len()
    );
    Ok(())
}

/// Matches `SeedJapanReferenceData#seed_admin_user` (migrate_archive).
fn seed_japan_admin_user(conn: &mut Connection) -> anyhow::Result<i64> {
    let now = context::now_rfc3339();

    let anonymous_id: i64 = match conn.query_row(
        "SELECT id FROM users WHERE is_anonymous = 1 LIMIT 1",
        [],
        |r| r.get(0),
    ) {
        Ok(id) => id,
        Err(rusqlite::Error::QueryReturnedNoRows) => {
            conn.execute(
                "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at)
                 VALUES (NULL, 'Anonymous', NULL, NULL, 1, 0, ?1, ?1)",
                params![now],
            )?;
            conn.last_insert_rowid()
        }
        Err(e) => return Err(e.into()),
    };

    if let Ok(admin_id) = conn.query_row(
        "SELECT id FROM users WHERE google_id = 'dev_user_001' LIMIT 1",
        [],
        |r| r.get::<_, i64>(0),
    ) {
        conn.execute(
            "UPDATE users SET email = 'developer@agrr.dev', name = '開発者', admin = 1, is_anonymous = 0, updated_at = ?1
             WHERE id = ?2",
            params![now, admin_id],
        )?;
    } else {
        conn.execute(
            "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at)
             VALUES ('developer@agrr.dev', '開発者', 'dev_user_001', NULL, 0, 1, ?1, ?1)",
            params![now],
        )?;
    }

    println!("  base/jp: admin user (developer@agrr.dev) ensured");
    Ok(anonymous_id)
}

struct JapanSampleFieldSpec {
    name_suffix: &'static str,
    area: f64,
    daily_fixed_cost: f64,
}

/// Matches `SeedJapanReferenceData#seed_sample_fields` (migrate_archive).
fn seed_japan_sample_fields(conn: &mut Connection) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    let field_specs = [
        JapanSampleFieldSpec {
            name_suffix: "第1圃場",
            area: 1000.0,
            daily_fixed_cost: 3000.0,
        },
        JapanSampleFieldSpec {
            name_suffix: "第2圃場",
            area: 1500.0,
            daily_fixed_cost: 4500.0,
        },
        JapanSampleFieldSpec {
            name_suffix: "第3圃場",
            area: 800.0,
            daily_fixed_cost: 2500.0,
        },
    ];
    let mut field_count = 0usize;

    with_transaction(conn, |tx| {
        let mut stmt = tx.prepare(
            "SELECT id, name, user_id FROM farms WHERE is_reference = 1 AND region = 'jp' ORDER BY id LIMIT 5",
        )?;
        let farms: Vec<(i64, String, Option<i64>)> = stmt
            .query_map([], |r| Ok((r.get(0)?, r.get(1)?, r.get(2)?)))?
            .collect::<Result<Vec<_>, _>>()?;

        for (farm_index, (farm_id, farm_name, farm_user_id)) in farms.iter().enumerate() {
            let farm_prefix: String = farm_name
                .chars()
                .filter(|c| *c != '県' && *c != '市')
                .collect::<String>()
                .trim()
                .chars()
                .take(3)
                .collect();
            let n_fields = farm_index % 2 + 2;
            for spec in field_specs.iter().take(n_fields) {
                let field_name = format!("{farm_prefix}_{}", spec.name_suffix);
                let exists: bool = tx
                    .query_row(
                        "SELECT 1 FROM fields WHERE farm_id = ?1 AND name = ?2 LIMIT 1",
                        params![farm_id, field_name],
                        |_| Ok(()),
                    )
                    .is_ok();
                if exists {
                    continue;
                }
                tx.execute(
                    "INSERT INTO fields (farm_id, user_id, name, area, daily_fixed_cost, region, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, 'jp', ?6, ?6)",
                    params![
                        farm_id,
                        farm_user_id,
                        field_name,
                        spec.area,
                        spec.daily_fixed_cost,
                        now
                    ],
                )?;
                field_count += 1;
            }
        }
        Ok(())
    })?;

    println!("  base/jp: {field_count} sample fields for reference farms");
    Ok(())
}

fn seed_india_inline_crops(conn: &mut Connection) -> anyhow::Result<()> {
    // Matches Rails `create_basic_crops_without_ai_data`: crops only, no crop_stages.
    let now = context::now_rfc3339();

    with_transaction(conn, |tx| {
        for crop in INDIA_INLINE_CROPS {
            let groups_json = serde_json::to_string(&crop.groups)?;
            upsert_crop(
                tx,
                crop.name,
                crop.variety,
                "in",
                crop.area_per_unit,
                crop.revenue_per_area,
                &groups_json,
                &now,
            )?;
        }
        Ok(())
    })?;

    println!(
        "  base/in: {} inline reference crops (no india_reference_crops.json; no stages)",
        INDIA_INLINE_CROPS.len()
    );
    Ok(())
}

fn interaction_impacts(region: &str) -> HashMap<&'static str, (f64, &'static str)> {
    match region {
        "jp" => [
            ("ナス科", (0.6, "ナス科の連作")),
            ("ウリ科", (0.65, "ウリ科の連作")),
            ("アブラナ科", (0.75, "アブラナ科の連作")),
            ("キク科", (0.75, "キク科の連作")),
            ("セリ科", (0.8, "セリ科の連作")),
            ("ネギ科", (0.85, "ネギ科の連作")),
            ("ヒユ科", (0.9, "ヒユ科の連作")),
            ("イネ科", (0.95, "イネ科の連作")),
        ]
        .into_iter()
        .collect(),
        "us" | "in" => [
            ("Solanaceae", (0.6, "Solanaceae continuous cultivation")),
            ("Cucurbitaceae", (0.65, "Cucurbitaceae continuous cultivation")),
            ("Malvaceae", (0.65, "Malvaceae continuous cultivation")),
            ("Brassicaceae", (0.75, "Brassicaceae continuous cultivation")),
            ("Asteraceae", (0.75, "Asteraceae continuous cultivation")),
            ("Zingiberaceae", (0.7, "Zingiberaceae continuous cultivation")),
            ("Apiaceae", (0.8, "Apiaceae continuous cultivation")),
            ("Amaryllidaceae", (0.85, "Amaryllidaceae continuous cultivation")),
            ("Amaranthaceae", (0.9, "Amaranthaceae continuous cultivation")),
            ("Poaceae", (0.95, "Poaceae continuous cultivation")),
            ("Fabaceae", (0.9, "Fabaceae continuous cultivation")),
            ("Theaceae", (0.9, "Theaceae continuous cultivation")),
            ("Rubiaceae", (0.85, "Rubiaceae continuous cultivation")),
            ("Arecaceae", (0.9, "Arecaceae continuous cultivation")),
            ("Anacardiaceae", (0.85, "Anacardiaceae continuous cultivation")),
        ]
        .into_iter()
        .collect(),
        _ => HashMap::new(),
    }
}
