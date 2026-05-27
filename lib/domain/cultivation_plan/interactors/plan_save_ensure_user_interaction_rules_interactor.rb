# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存: 参照連作ルールをユーザー連作ルールとして確保する。
      class PlanSaveEnsureUserInteractionRulesInteractor
        def initialize(read_gateway:, user_interaction_rule_gateway:, logger:, translator:)
          @read_gateway = read_gateway
          @user_interaction_rule_gateway = user_interaction_rule_gateway
          @logger = logger
          @translator = translator
        end

        # @param input_dto [Dtos::PlanSaveEnsureUserInteractionRulesInput]
        # @return [Dtos::PlanSaveEnsureUserInteractionRulesOutput]
        # @raise [Domain::Shared::Exceptions::RecordInvalid]
        def call(input_dto)
          if input_dto.reference_crop_groups.empty?
            return empty_output
          end

          rows = @read_gateway.list_interaction_rule_reference_rows(region: input_dto.region)
          crop_groups = input_dto.reference_crop_groups

          user_interaction_rule_ids = []
          skipped_interaction_rule_ids = []

          rows.each do |row|
            next unless row_matches_plan_crop_groups?(row, crop_groups)

            existing = find_existing_rule(input_dto.user_id, row)

            if existing
              link_source_if_needed!(input_dto.user_id, existing, row)
              skipped_interaction_rule_ids << existing.id
              user_interaction_rule_ids << existing.id
              next
            end

            attributes = Mappers::PlanSaveInteractionRuleAttributesMapper.attributes_for_create(row: row)
            created = @user_interaction_rule_gateway.create(
              user_id: input_dto.user_id,
              attributes: attributes
            )

            user_interaction_rule_ids << created.id
            @logger.info(
              @translator.t(
                "services.plan_save_service.messages.interaction_rule_created",
                source_group: row.source_group,
                target_group: row.target_group
              )
            )
          end

          Dtos::PlanSaveEnsureUserInteractionRulesOutput.new(
            user_interaction_rule_ids: user_interaction_rule_ids,
            skipped_interaction_rule_ids: skipped_interaction_rule_ids
          )
        end

        private

        def empty_output
          Dtos::PlanSaveEnsureUserInteractionRulesOutput.new(
            user_interaction_rule_ids: [],
            skipped_interaction_rule_ids: []
          )
        end

        def row_matches_plan_crop_groups?(row, crop_groups)
          crop_groups.include?(row.source_group) || crop_groups.include?(row.target_group)
        end

        def find_existing_rule(user_id, row)
          by_source = @user_interaction_rule_gateway.find_by_user_id_and_source_interaction_rule_id(
            user_id: user_id,
            source_interaction_rule_id: row.reference_interaction_rule_id
          )
          return by_source if by_source

          @user_interaction_rule_gateway.find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
            user_id: user_id,
            rule_type: row.rule_type,
            source_group: row.source_group,
            target_group: row.target_group,
            region: row.region
          )
        end

        def link_source_if_needed!(user_id, existing, row)
          return if existing.source_interaction_rule_id

          @user_interaction_rule_gateway.update(
            user_id: user_id,
            interaction_rule_id: existing.id,
            attributes: { source_interaction_rule_id: row.reference_interaction_rule_id }
          )
        end
      end
    end
  end
end
