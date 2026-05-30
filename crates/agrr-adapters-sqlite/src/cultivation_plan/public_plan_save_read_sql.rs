//! Shared SQL helpers for [`PublicPlanSaveReadSqliteGateway`] (Rails region filter parity).

/// `is_reference = 1` with optional `region IS NULL OR region = ?`.
pub(crate) fn reference_region_where(region: Option<&str>) -> (&'static str, bool) {
    match region {
        Some(_) => (
            "is_reference = 1 AND (region IS NULL OR region = ?1)",
            true,
        ),
        None => ("is_reference = 1", false),
    }
}

pub(crate) fn plan_exists(conn: &rusqlite::Connection, plan_id: i64) -> rusqlite::Result<bool> {
    let n: i64 = conn.query_row(
        "SELECT COUNT(*) FROM cultivation_plans WHERE id = ?1",
        rusqlite::params![plan_id],
        |r| r.get(0),
    )?;
    Ok(n > 0)
}
