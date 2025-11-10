# frozen_string_literal: true

require 'test_helper'
require 'logger'

module DeletionUndo
  class FarmPreparationServiceTest < ActiveSupport::TestCase
    setup do
      ActiveJob::Base.queue_adapter = :test
      @user = User.create!(
        email: 'cleanup@example.com',
        name: 'Cleanup User',
        google_id: 'cleanup-user',
        avatar_url: 'dev-avatar.svg'
      )
    end

    test 'prepares target farms and resets associations' do
      crop = @user.crops.create!(
        name: 'Legacy Crop',
        is_reference: false,
        variety: 'Legacy',
        area_per_unit: 0.5,
        revenue_per_area: 4000
      )

      legacy_farms = Array.new(4) do |index|
        create_farm!("Legacy Farm #{index}", 30.0 + index, 130.0 + index)
      end

      legacy_field = legacy_farms.first.fields.create!(name: 'Legacy Field', area: 80, user: @user)
      legacy_plan = FreeCropPlan.create!(farm: legacy_farms.second, crop: crop, area_sqm: 200)

      result = FarmPreparationService.new(user_google_id: @user.google_id, logger: Logger.new(nil)).call

      target_names = DeletionUndo::FarmPreparationService::TARGET_FARMS.map { |config| config[:name] }
      assert_equal target_names.sort, @user.farms.user_owned.pluck(:name).sort
      assert_equal 4, @user.farms.user_owned.count

      refute FreeCropPlan.exists?(legacy_plan.id), 'free crop plan should be removed with its farm'
      refute Field.exists?(legacy_field.id), 'legacy field should be removed during reset'

      field_farm = @user.farms.find(result.fetch(:field_farm_id))
      field = @user.fields.find_by!(farm: field_farm, name: DeletionUndo::FarmPreparationService::FIELD_NAME)
      assert_equal DeletionUndo::FarmPreparationService::FIELD_AREA, field.area
    end

    test 'reuses existing selenium farms without duplication' do
      existing = {}
      DeletionUndo::FarmPreparationService::TARGET_FARMS.each do |config|
        existing[config[:key]] = create_farm!(config[:name], config[:latitude], config[:longitude])
      end

      result = FarmPreparationService.new(user_google_id: @user.google_id, logger: Logger.new(nil)).call

      assert_equal existing[:basic].id, result[:timeout_farm_id]
      assert_equal existing[:field].id, result[:field_farm_id]
      assert_equal existing[:sequential_a].id, result[:seq_a_farm_id]
      assert_equal existing[:sequential_b].id, result[:seq_b_farm_id]
    end

    private

    def create_farm!(name, latitude, longitude)
      @user.farms.create!(
        name: name,
        latitude: latitude,
        longitude: longitude,
        is_reference: false
      )
    end
  end
end
