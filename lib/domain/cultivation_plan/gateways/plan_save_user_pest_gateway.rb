# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー害虫の検索・作成・関連付け（狭い永続化ポート）。
      class PlanSaveUserPestGateway
        # @return [Dtos::PlanSaveUserPestSnapshot, nil]
        def find_by_user_id_and_source_pest_id(user_id:, source_pest_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserPestSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end

        # @param pest_id [Integer]
        # @param attributes [Hash]
        def create_temperature_profile(pest_id:, attributes:)
          raise NotImplementedError
        end

        # @param pest_id [Integer]
        # @param attributes [Hash]
        def create_thermal_requirement(pest_id:, attributes:)
          raise NotImplementedError
        end

        # @param pest_id [Integer]
        # @param attributes [Hash]
        def create_control_method(pest_id:, attributes:)
          raise NotImplementedError
        end

        # @param crop_id [Integer]
        # @param pest_id [Integer]
        def link_crop_pest(crop_id:, pest_id:)
          raise NotImplementedError
        end
      end
    end
  end
end
