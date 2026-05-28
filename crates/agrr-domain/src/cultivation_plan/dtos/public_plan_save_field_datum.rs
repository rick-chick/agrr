//! Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveFieldDatum`

use std::collections::BTreeMap;

use serde_json::Value;

/// Ruby: `Domain::CultivationPlan::Dtos::PublicPlanSaveFieldDatum`
#[derive(Debug, Clone, PartialEq)]
pub struct PublicPlanSaveFieldDatum {
    pub name: Option<String>,
    pub area: Option<f64>,
    pub coordinates: Vec<f64>,
}

impl PublicPlanSaveFieldDatum {
    pub fn new(
        name: Option<impl Into<String>>,
        area: Option<f64>,
        coordinates: Vec<f64>,
    ) -> Self {
        Self {
            name: name.map(Into::into),
            area,
            coordinates,
        }
    }

    pub fn from_row(row: &Value) -> Option<Self> {
        let obj = row.as_object()?;
        Some(Self::new(
            Self::map_get(obj, "name").and_then(|v| match v {
                Value::Null => None,
                Value::String(s) => Some(s.clone()),
                Value::Number(n) => Some(n.to_string()),
                _ => None,
            }),
            Self::map_get(obj, "area").and_then(|v| v.as_f64()),
            Self::map_get(obj, "coordinates")
                .map(|v| match v {
                    Value::Array(arr) => arr.iter().filter_map(|x| x.as_f64()).collect(),
                    _ => vec![],
                })
                .unwrap_or_default(),
        ))
    }

    pub fn to_session_row(&self) -> BTreeMap<String, Value> {
        let mut map = BTreeMap::new();
        if let Some(name) = &self.name {
            map.insert("name".into(), Value::String(name.clone()));
        }
        if let Some(area) = self.area {
            map.insert("area".into(), Value::from(area));
        }
        map.insert(
            "coordinates".into(),
            Value::Array(
                self.coordinates
                    .iter()
                    .map(|c| Value::from(*c))
                    .collect(),
            ),
        );
        map
    }

    fn map_get<'a>(h: &'a serde_json::Map<String, Value>, key: &str) -> Option<&'a Value> {
        h.get(key)
    }
}
