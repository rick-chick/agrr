use crate::field_cultivation::dtos::{
    CultivationPlanWeatherInput, FieldCultivationClimateSourceSnapshot,
};

pub fn to_cultivation_plan_weather(
    source: &FieldCultivationClimateSourceSnapshot,
) -> CultivationPlanWeatherInput {
    CultivationPlanWeatherInput {
        id: source.plan_id,
        prediction_target_end_date: source.prediction_target_end_date,
        calculated_planning_end_date: source.calculated_planning_end_date,
        predicted_weather_data: source.predicted_weather_data.clone(),
    }
}
