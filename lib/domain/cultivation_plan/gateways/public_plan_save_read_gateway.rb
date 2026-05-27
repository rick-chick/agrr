# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # 公開プラン保存の読取専用（認可・組み立ては Interactor + domain mapper）。
      class PublicPlanSaveReadGateway
        # @return [Dtos::PublicPlanSaveHeaderSnapshot, nil]
        def find_header(plan_id:)
          raise NotImplementedError
        end

        # @return [Array<Dtos::PublicPlanSaveFieldDatum>]
        def list_field_rows(plan_id:)
          raise NotImplementedError
        end

        # @param plan_id [Integer]
        # @return [Array<Dtos::PublicPlanSaveCropReferenceRow>]
        def list_crop_reference_rows(plan_id:)
          raise NotImplementedError
        end

        # @param plan_id [Integer]
        # @param region [String, nil]
        # @return [Array<Dtos::PublicPlanSavePestReferenceRow>]
        def list_pest_reference_rows(plan_id:, region:)
          raise NotImplementedError
        end

        # @param region [String, nil]
        # @return [Array<Dtos::PublicPlanSavePesticideReferenceRow>]
        def list_pesticide_reference_rows(region:)
          raise NotImplementedError
        end

        # @param region [String, nil]
        # @return [Array<Dtos::PublicPlanSaveFertilizeReferenceRow>]
        def list_fertilize_reference_rows(region:)
          raise NotImplementedError
        end

        # @param name [String]
        # @return [Boolean]
        def exists_fertilize_name?(name:)
          raise NotImplementedError
        end

        # @param region [String, nil]
        # @return [Array<Dtos::PublicPlanSaveAgriculturalTaskReferenceRow>]
        def list_agricultural_task_reference_rows(region:)
          raise NotImplementedError
        end

        # @param region [String, nil]
        # @return [Array<Dtos::PublicPlanSaveInteractionRuleReferenceRow>]
        def list_interaction_rule_reference_rows(region:)
          raise NotImplementedError
        end
      end
    end
  end
end
