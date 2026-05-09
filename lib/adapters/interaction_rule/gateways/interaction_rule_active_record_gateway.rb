# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Gateways
      class InteractionRuleActiveRecordGateway < Domain::InteractionRule::Gateways::InteractionRuleGateway
        attr_accessor :translator

        def initialize(deletion_undo_gateway:, translator:)
          @deletion_undo_gateway = deletion_undo_gateway
          @translator = translator
        end

        def find_by_id(rule_id)
          rule = ::InteractionRule.find(rule_id)
          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(rule)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "InteractionRule not found"
        end

        def create(create_input_dto)
          rule = ::InteractionRule.new(
            rule_type: create_input_dto.rule_type,
            source_group: create_input_dto.source_group,
            target_group: create_input_dto.target_group,
            impact_ratio: create_input_dto.impact_ratio,
            is_directional: create_input_dto.is_directional,
            description: create_input_dto.description,
            region: create_input_dto.region,
            is_reference: create_input_dto.is_reference
          )
          raise Domain::Shared::Exceptions::RecordInvalid, rule.errors.full_messages.join(", ") unless rule.save

          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(rule)
        end

        def update(rule_id, update_input_dto)
          rule = ::InteractionRule.find(rule_id)
          attrs = {}
          attrs[:rule_type] = update_input_dto.rule_type if update_input_dto.rule_type.present?
          attrs[:source_group] = update_input_dto.source_group if update_input_dto.source_group.present?
          attrs[:target_group] = update_input_dto.target_group if update_input_dto.target_group.present?
          attrs[:impact_ratio] = update_input_dto.impact_ratio if !update_input_dto.impact_ratio.nil?
          attrs[:is_directional] = update_input_dto.is_directional if !update_input_dto.is_directional.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          rule.update(attrs)
          raise Domain::Shared::Exceptions::RecordInvalid, rule.errors.full_messages.join(", ") if rule.errors.any?

          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(rule.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "InteractionRule not found"
        end

        def destroy(rule_id)
          rule = ::InteractionRule.find(rule_id)
          rule.destroy!
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "InteractionRule not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise Domain::Shared::Exceptions::AssociationInUse, @translator.t("interaction_rules.flash.cannot_delete_in_use")
        end

        def agrr_rules_for_cultivation_plan_id(cultivation_plan_id)
          cultivation_plan = ::CultivationPlan.find(cultivation_plan_id)
          farm_region = cultivation_plan.farm.region

          rules = if cultivation_plan.user_id
            ::InteractionRule.where(
              "((user_id = ? AND is_reference = ?) OR is_reference = ?) AND region = ?",
              cultivation_plan.user_id,
              false,
              true,
              farm_region
            )
          else
            ::InteractionRule.reference.where(region: farm_region)
          end

          rules_array = ::InteractionRule.to_agrr_format_array(rules)
          return nil if rules_array.empty?

          rules_array
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(record) }
        end

        private

        def index_relation_for_filter(filter)
          case filter.mode
          when :reference_or_owned
            ::InteractionRule.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            ::InteractionRule.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
          end
        end

        public

        def find_authorized_model_for_view(user, id)
          rule = find_interaction_rule_model!(id)
          unless Domain::Shared::Policies::InteractionRulePolicy.view_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          rule
        end

        def find_authorized_model_for_edit(user, id)
          rule = find_interaction_rule_model!(id)
          unless Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          rule
        end

        def find_authorized_for_view(user, id)
          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(user, attrs)
          rule = ::InteractionRule.new(h)
          raise Domain::Shared::Exceptions::RecordInvalid, rule.errors.full_messages.join(", ") unless rule.save

          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(rule)
        end

        def update_for_user(user, id, attrs)
          rule = find_interaction_rule_model!(id)
          unless Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_update(
            user,
            rule.attributes.symbolize_keys,
            attrs
          )
          raise Domain::Shared::Exceptions::RecordInvalid, rule.errors.full_messages.join(", ") unless rule.update(normalized)

          Adapters::InteractionRule::Mappers::InteractionRuleMapper.interaction_rule_entity_from_record(rule.reload)
        end

        def soft_destroy_with_undo(user:, rule_id:, auto_hide_after: 5000, translator:)
          rule = find_interaction_rule_model!(rule_id)
          unless Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          toast_message = translator.t("interaction_rules.undo.toast", source: rule.source_group, target: rule.target_group)
          event = @deletion_undo_gateway.schedule(
            resource_type: rule.class.name,
            resource_id: rule.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        private

        def find_interaction_rule_model!(id)
          ::InteractionRule.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
