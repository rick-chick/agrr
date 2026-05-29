//! Ruby: `Domain::CultivationPlan::Interactors::PlanSavePersistOrchestrator`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserFarmInput, PlanSaveEnsureUserFarmOutput, PublicPlanSaveSessionData,
};

pub enum PlanSaveSessionRef<'a> {
    Json(&'a BTreeMap<String, Value>),
    Dto(&'a PublicPlanSaveSessionData),
}

pub struct PlanSavePersistOrchestrator<'a, I> {
    ensure_user_farm_interactor: &'a I,
}

impl<'a, I> PlanSavePersistOrchestrator<'a, I> {
    pub fn new(ensure_user_farm_interactor: &'a I) -> Self {
        Self {
            ensure_user_farm_interactor,
        }
    }

    pub fn ensure_user_farm(
        &self,
        user_id: i64,
        session_data: PlanSaveSessionRef<'_>,
    ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>>
    where
        I: PlanSaveEnsureUserFarmPort,
    {
        let reference_farm_id = extract_reference_farm_id_from_session(session_data)
            .ok_or_else(|| "missing farm_id".to_string())?;
        self.ensure_user_farm_interactor.execute(PlanSaveEnsureUserFarmInput {
            user_id,
            reference_farm_id,
        })
    }
}

pub trait PlanSaveEnsureUserFarmPort {
    fn execute(
        &self,
        input: PlanSaveEnsureUserFarmInput,
    ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>>;
}

impl<'a, G, L, T, C> PlanSaveEnsureUserFarmPort
    for crate::cultivation_plan::interactors::PlanSaveEnsureUserFarmInteractor<'a, G, L, T, C>
where
    G: crate::cultivation_plan::gateways::PlanSaveFarmGateway,
    L: crate::shared::ports::LoggerPort,
    T: crate::shared::ports::TranslatorPort,
    C: crate::shared::ports::ClockPort,
{
    fn execute(
        &self,
        input: PlanSaveEnsureUserFarmInput,
    ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>> {
        crate::cultivation_plan::interactors::PlanSaveEnsureUserFarmInteractor::call(self, input)
    }
}

fn extract_reference_farm_id_from_session(session_data: PlanSaveSessionRef<'_>) -> Option<i64> {
    let raw = match session_data {
        PlanSaveSessionRef::Json(map) => map.get("farm_id").cloned(),
        PlanSaveSessionRef::Dto(dto) => dto.farm_id.map(Value::from),
    };
    let raw = raw?;
    match raw {
        Value::Null => None,
        Value::String(s) if s.trim().is_empty() => None,
        Value::String(s) => s.parse().ok(),
        Value::Number(n) => n.as_i64(),
        _ => None,
    }
}

#[cfg(test)]
mod interactors_plan_save_persist_orchestrator_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_persist_orchestrator_test.rs"));
}
