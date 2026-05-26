# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存フロー専用の狭い農場永続化ポート（参照農場の解決・ユーザー農場の再利用／作成）。
      class PlanSaveFarmGateway
        # @param farm_id [Integer, nil]
        # @return [Object, nil] duck: #id, #name, #latitude, #longitude, #region, #weather_location_id
        def find_reference_farm(farm_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param source_farm_id [Integer]
        # @return [Object, nil] duck: #id, #name, #region
        def find_user_farm_by_source(user_id:, source_farm_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @return [Integer]
        def count_non_reference_farms(user_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param reference_farm_id [Integer]
        # @param copy_name_suffix [String] 例: Time#strftime("%Y%m%d_%H%M%S")（UTC）
        # @return [Object] duck: #id, #name, #region
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create_user_farm_from_reference(user_id:, reference_farm_id:, copy_name_suffix:)
          raise NotImplementedError
        end

        # Template-copy 境界: ユーザー所有の農場 AR（存在しなければ nil）
        # @param user_id [Integer]
        # @param farm_id [Integer]
        def find_owned_farm_record(user_id:, farm_id:)
          raise NotImplementedError
        end

        # Template-copy 境界: ユーザー・農場に紐づく private 計画 AR（存在しなければ nil）
        # @param user_id [Integer]
        # @param farm_id [Integer]
        def find_owned_private_plan_record(user_id:, farm_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
