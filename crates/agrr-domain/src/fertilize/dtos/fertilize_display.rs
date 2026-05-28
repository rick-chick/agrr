use crate::fertilize::entities::FertilizeEntity;
use crate::shared::hash::blank_attr;

/// Ruby: `Domain::Fertilize::Dtos::FertilizeDisplay`
#[derive(Debug, Clone, PartialEq)]
pub struct FertilizeDisplay {
    pub id: Option<i64>,
    pub name: String,
    pub n: Option<f64>,
    pub p: Option<f64>,
    pub k: Option<f64>,
    pub description: Option<String>,
    pub package_size: Option<f64>,
    pub is_reference: bool,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}

impl FertilizeDisplay {
    pub fn new(fertilize_entity: &FertilizeEntity) -> Self {
        Self {
            id: fertilize_entity.id,
            name: fertilize_entity.name.clone(),
            n: fertilize_entity.n,
            p: fertilize_entity.p,
            k: fertilize_entity.k,
            description: fertilize_entity.description.clone(),
            package_size: fertilize_entity.package_size,
            is_reference: fertilize_entity.is_reference,
            created_at: fertilize_entity.created_at.clone(),
            updated_at: fertilize_entity.updated_at.clone(),
        }
    }

    pub fn persisted(&self) -> bool {
        self.id.map(|id| !blank_attr(&crate::shared::attr::AttrValue::Int(id))).unwrap_or(false)
    }

    pub fn npk_summary(&self) -> String {
        [self.n, self.p, self.k]
            .into_iter()
            .flatten()
            .map(|v| v.trunc() as i64)
            .map(|v| v.to_string())
            .collect::<Vec<_>>()
            .join("-")
    }
}
