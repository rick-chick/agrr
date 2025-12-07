# frozen_string_literal: true

require "test_helper"

class Api::V1::FieldCultivationProgressI18nTest < ActionController::TestCase
  tests Api::V1::Plans::FieldCultivationsController

  test "mock progress uses translated stage names" do
    I18n.locale = :ja
    start_date = Date.today
    end_date = start_date + 90.days

    records = @controller.send(:generate_mock_progress_records, start_date, end_date)
    translated_stage_names = I18n.t('controllers.field_cultivations.mock_progress.stage_names')

    assert records.present?, "mock progress records should be generated"
    assert (records.map { |r| r['stage_name'] }.uniq - translated_stage_names).empty?, "stage names should be translated"
  end
end

