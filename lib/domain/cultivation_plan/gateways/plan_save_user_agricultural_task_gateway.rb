# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存: ユーザー農作業の検索・作成・CropTaskTemplate 紐づけ。
      class PlanSaveUserAgriculturalTaskGateway
        # @return [Dtos::PlanSaveUserAgriculturalTaskSnapshot, nil]
        def find_by_user_id_and_source_agricultural_task_id(user_id:, source_agricultural_task_id:)
          raise NotImplementedError
        end

        # @param user_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveUserAgriculturalTaskSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create(user_id:, attributes:)
          raise NotImplementedError
        end

        # @return [Dtos::PlanSaveCropTaskTemplateLinkSnapshot, nil]
        def find_crop_task_template(crop_id:, agricultural_task_id:)
          raise NotImplementedError
        end

        # @param crop_id [Integer]
        # @param agricultural_task_id [Integer]
        # @param attributes [Hash]
        # @return [Dtos::PlanSaveCropTaskTemplateLinkSnapshot]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def create_crop_task_template(crop_id:, agricultural_task_id:, attributes:)
          raise NotImplementedError
        end
      end
    end
  end
end
