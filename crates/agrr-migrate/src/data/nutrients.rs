use super::context::{self, with_transaction};
use rusqlite::{params, Connection};

pub fn apply(conn: &mut Connection, region: &str) -> anyhow::Result<()> {
    let now = context::now_rfc3339();
    let mut count = 0usize;

    with_transaction(conn, |tx| {
        let mut stmt = tx.prepare(
            "SELECT cs.id, cs.name, cs.\"order\", c.name
             FROM crop_stages cs
             INNER JOIN crops c ON c.id = cs.crop_id
             WHERE c.region = ?1 AND c.is_reference = 1",
        )?;
        let rows = stmt.query_map(params![region], |r| {
            Ok((
                r.get::<_, i64>(0)?,
                r.get::<_, String>(1)?,
                r.get::<_, i64>(2)?,
                r.get::<_, String>(3)?,
            ))
        })?;

        for row in rows {
            let (stage_id, stage_name, stage_order, crop_name) = row?;
            let values = calculate_nutrient_values(region, &crop_name, &stage_name, stage_order);
            let existing: Option<i64> = tx
                .query_row(
                    "SELECT id FROM nutrient_requirements WHERE crop_stage_id = ?1 AND region = ?2 AND is_reference = 1",
                    params![stage_id, region],
                    |r| r.get(0),
                )
                .optional()
                .ok()
                .flatten();

            if let Some(id) = existing {
                tx.execute(
                    "UPDATE nutrient_requirements SET daily_uptake_n = ?1, daily_uptake_p = ?2, daily_uptake_k = ?3,
                     updated_at = ?4 WHERE id = ?5",
                    params![values.0, values.1, values.2, now, id],
                )?;
            } else {
                tx.execute(
                    "INSERT INTO nutrient_requirements (crop_stage_id, daily_uptake_n, daily_uptake_p, daily_uptake_k,
                     region, is_reference, created_at, updated_at)
                     VALUES (?1, ?2, ?3, ?4, ?5, 1, ?6, ?6)",
                    params![stage_id, values.0, values.1, values.2, region, now],
                )?;
            }
            count += 1;
        }
        Ok(())
    })?;

    println!("  nutrients/{region}: {count} nutrient_requirements upserted");
    Ok(())
}

fn calculate_nutrient_values(
    region: &str,
    crop_name: &str,
    _stage_name: &str,
    stage_order: i64,
) -> (f64, f64, f64) {
    let base_n = 0.5;
    let base_p = 0.2;
    let base_k = 0.3;

    let multiplier = match stage_order {
        1 => 0.3,
        2 => 0.6,
        3 => 1.0,
        4 => 0.8,
        _ => 0.5,
    };

    let crop_multiplier = crop_multiplier_for(region, crop_name);

    let n = (base_n * multiplier * crop_multiplier * 100.0).round() / 100.0;
    let p = (base_p * multiplier * crop_multiplier * 100.0).round() / 100.0;
    let k = (base_k * multiplier * crop_multiplier * 100.0).round() / 100.0;
    (n, p, k)
}

fn crop_multiplier_for(region: &str, crop_name: &str) -> f64 {
    match region {
        "jp" => match crop_name {
            "トマト" | "ナス" | "ピーマン" => 1.2,
            "キャベツ" | "白菜" | "ブロッコリー" => 1.1,
            "ジャガイモ" | "ニンジン" | "大根" | "玉ねぎ" => 0.9,
            _ => 1.0,
        },
        "us" => match crop_name {
            "Tomato" | "Eggplant" | "Bell Pepper" => 1.2,
            "Cabbage" | "Lettuce" | "Broccoli" => 1.1,
            "Potato" | "Carrot" | "Onion" => 0.9,
            _ => 1.0,
        },
        "in" => match crop_name {
            "टमाटर" | "बैंगन" | "मिर्च" => 1.2,
            "पत्ता गोभी" | "फूल गोभी" => 1.1,
            "आलू" | "प्याज" | "अदरक" | "हल्दी" => 0.9,
            "आम" | "नारियल" | "इलायची" | "कॉफी" | "चाय" => 1.1,
            _ => 1.0,
        },
        _ => 1.0,
    }
}

trait OptionalRow {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error>;
}

impl OptionalRow for Result<i64, rusqlite::Error> {
    fn optional(self) -> Result<Option<i64>, rusqlite::Error> {
        match self {
            Ok(v) => Ok(Some(v)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }
}
