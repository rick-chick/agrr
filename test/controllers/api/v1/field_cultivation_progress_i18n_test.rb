# frozen_string_literal: true

require "test_helper"

class Api::V1::FieldCultivationProgressI18nTest < ActiveSupport::TestCase
  test "mock progress uses translated stage names" do
    I18n.locale = :ja
    start_date = Date.today
    end_date = start_date + 90.days
    logger = Adapters::Shared::Ports::RailsLoggerAdapter.new
    gateway = Adapters::FieldCultivation::Gateways::FieldCultivationClimateProgressMemoryGateway.new(logger: logger)
    crop_entity = Domain::Crop::Entities::CropEntity.new(
      id: 1,
      user_id: 1,
      name: "tomato",
      variety: nil,
      is_reference: false
    )

    result = gateway.calculate_progress(
      crop_entity: crop_entity,
      start_date: start_date,
      weather_payload: { "data" => [] }
    )
    records = result["progress_records"]
    translated_stage_names = I18n.t("controllers.field_cultivations.mock_progress.stage_names")

    assert records.present?, "mock progress records should be generated"
    assert (records.map { |r| r["stage_name"] }.uniq - translated_stage_names).empty?, "stage names should be translated"
  end
end
