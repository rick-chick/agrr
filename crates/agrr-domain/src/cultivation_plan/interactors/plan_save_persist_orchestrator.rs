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
mod tests {
    use super::*;
    use serde_json::json;

    struct MockFarmInteractor {
        expected_user_id: i64,
        expected_reference_farm_id: i64,
        output: PlanSaveEnsureUserFarmOutput,
    }

    impl PlanSaveEnsureUserFarmPort for MockFarmInteractor {
        fn execute(
            &self,
            input: PlanSaveEnsureUserFarmInput,
        ) -> Result<PlanSaveEnsureUserFarmOutput, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(input.user_id, self.expected_user_id);
            assert_eq!(input.reference_farm_id, self.expected_reference_farm_id);
            Ok(self.output.clone())
        }
    }

    // Ruby: test "ensure_user_farm delegates to interactor with farm_id from session hash"
    #[test]
    fn ensure_user_farm_delegates_with_farm_id_from_session_hash() {
        let mut map = BTreeMap::new();
        map.insert("farm_id".into(), json!(10));
        let interactor = MockFarmInteractor {
            expected_user_id: 5,
            expected_reference_farm_id: 10,
            output: PlanSaveEnsureUserFarmOutput {
                farm_id: 77,
                farm_reused: false,
                farm_region: Some("jp".into()),
            },
        };
        let orchestrator = PlanSavePersistOrchestrator::new(&interactor);
        let out = orchestrator
            .ensure_user_farm(5, PlanSaveSessionRef::Json(&map))
            .unwrap();
        assert_eq!(out.farm_id, 77);
    }

    // Ruby: test "ensure_user_farm reads farm_id from PublicPlanSaveSessionData"
    #[test]
    fn ensure_user_farm_reads_farm_id_from_public_plan_save_session_data() {
        let interactor = MockFarmInteractor {
            expected_user_id: 3,
            expected_reference_farm_id: 12,
            output: PlanSaveEnsureUserFarmOutput {
                farm_id: 1,
                farm_reused: true,
                farm_region: Some("jp".into()),
            },
        };
        let session = PublicPlanSaveSessionData::new(1, Some(12), vec![], None);
        PlanSavePersistOrchestrator::new(&interactor)
            .ensure_user_farm(3, PlanSaveSessionRef::Dto(&session))
            .unwrap();
    }
}
