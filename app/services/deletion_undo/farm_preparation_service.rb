# frozen_string_literal: true

module DeletionUndo
  # Selenium向けUndoシナリオで使用するFarmを事前に整理・準備するサービス
  #
  # - dev_user_001 が保持するユーザー農場を上限4件以内に整理する
  # - 既存Farmを再利用しつつ、テストで利用する名称・座標に統一する
  # - Seleniumシナリオで利用するField（`Selenium Field 20251110`）も整備する
  class FarmPreparationService
    TARGET_FARMS = [
      {
        key: :basic,
        name: 'Selenium Farm Timeout 20251110',
        latitude: 34.5,
        longitude: 134.5
      },
      {
        key: :field,
        name: 'Selenium Farm 20251110',
        latitude: 35.0,
        longitude: 135.0
      },
      {
        key: :sequential_a,
        name: 'Selenium Farm Sequential A 20251110',
        latitude: 34.6,
        longitude: 134.6
      },
      {
        key: :sequential_b,
        name: 'Selenium Farm Sequential B 20251110',
        latitude: 34.7,
        longitude: 134.7
      }
    ].freeze

    FIELD_NAME = 'Selenium Field 20251110'
    FIELD_AREA = 100

    def initialize(user_google_id:, logger: Rails.logger)
      @user_google_id = user_google_id
      @logger = logger
    end

    def call
      user = User.find_by!(google_id: user_google_id)

      prepared_farms = nil
      ActiveRecord::Base.transaction do
        prepared_farms = ensure_target_farms(user)
        ensure_field_for_farm(user, prepared_farms.fetch(:field))
      end

      {
        field_farm_id: prepared_farms.fetch(:field).id,
        timeout_farm_id: prepared_farms.fetch(:basic).id,
        seq_a_farm_id: prepared_farms.fetch(:sequential_a).id,
        seq_b_farm_id: prepared_farms.fetch(:sequential_b).id
      }
    end

    private

    attr_reader :user_google_id, :logger

    def ensure_target_farms(user)
      reserved = {}
      leftovers = user.farms.user_owned.order(created_at: :asc).to_a

      # 1. 既に目的の名前を持つFarmを優先的に確保
      TARGET_FARMS.each do |target|
        match = leftovers.find { |farm| farm.name.casecmp?(target[:name]) }
        next unless match

        reserved[target[:key]] = prepare_farm!(match, target)
        leftovers.delete(match)
      end

      # 2. 未割り当てのターゲットについては既存Farmを再利用
      TARGET_FARMS.reject { |target| reserved.key?(target[:key]) }.each do |target|
        candidate = leftovers.shift
        next unless candidate

        reserved[target[:key]] = repurpose_farm!(candidate, target)
      end

      # 3. 残余のFarmは削除を試みる
      leftovers.each { |farm| destroy_farm!(farm) }

      # 4. まだ不足しているFarmは新規に作成
      TARGET_FARMS.reject { |target| reserved.key?(target[:key]) }.each do |target|
        reserved[target[:key]] = create_farm!(user, target)
      end

      reserved
    end

    def prepare_farm!(farm, target)
      reset_farm_associations!(farm)
      synchronize_attributes!(farm, target)
      farm
    end

    def repurpose_farm!(farm, target)
      reset_farm_associations!(farm)
      farm.name = target[:name]
      synchronize_attributes!(farm, target)
      farm
    end

    def create_farm!(user, target)
      user.farms.create!(
        name: target[:name],
        latitude: target[:latitude],
        longitude: target[:longitude],
        is_reference: false
      )
    end

    def destroy_farm!(farm)
      reset_farm_associations!(farm)
      farm.destroy!
    rescue StandardError => e
      logger.warn("[DeletionUndo::FarmPreparationService] Farm destroy skipped for #{farm.id}: #{e.message}")
    end

    def reset_farm_associations!(farm)
      if farm.user
        farm.user.cultivation_plans.where(farm: farm).destroy_all
      end
      farm.fields.destroy_all
      farm.free_crop_plans.destroy_all
    end

    def synchronize_attributes!(farm, target)
      farm.update!(
        latitude: target[:latitude],
        longitude: target[:longitude],
        is_reference: false,
        source_farm_id: nil,
        region: nil,
        weather_data_status: 'pending',
        weather_data_fetched_years: 0,
        weather_data_total_years: 0,
        weather_data_last_error: nil
      )
    end

    def ensure_field_for_farm(user, farm)
      user.fields.find_or_create_by!(farm: farm, name: FIELD_NAME) do |field|
        field.area = FIELD_AREA
      end
    end
  end
end
