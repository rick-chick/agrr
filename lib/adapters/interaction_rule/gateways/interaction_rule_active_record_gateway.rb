# frozen_string_literal: true

module Adapters
  module InteractionRule
    module Gateways
      class InteractionRuleActiveRecordGateway < Domain::InteractionRule::Gateways::InteractionRuleGateway
        attr_accessor :translator
        def list(scope = nil)
          query = scope || ::InteractionRule.all
          query.map { |record| Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(record) }
        end

        def find_by_id(rule_id)
          rule = ::InteractionRule.find(rule_id)
          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "InteractionRule not found"
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
          raise StandardError, rule.errors.full_messages.join(", ") unless rule.save

          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule)
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
          raise StandardError, rule.errors.full_messages.join(", ") if rule.errors.any?

          Domain::InteractionRule::Entities::InteractionRuleEntity.from_model(rule.reload)
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "InteractionRule not found"
        end

        def destroy(rule_id)
          rule = ::InteractionRule.find(rule_id)
          rule.destroy!
        rescue ActiveRecord::RecordNotFound
          raise StandardError, "InteractionRule not found"
        rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
          raise StandardError, @translator.t("interaction_rules.flash.cannot_delete_in_use")
        end

        def agrr_rules_for_cultivation_plan(cultivation_plan)
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
        end

        def visible_records(user)
          if user.admin?
            ::InteractionRule.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::InteractionRule.where(user_id: user.id, is_reference: false)
          end
        end

        def find_authorized_for_view(user, id)
          rule = find_interaction_rule_model!(id)
          unless Domain::Shared::Policies::InteractionRulePolicy.view_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          rule
        end

        def find_authorized_for_edit(user, id)
          rule = find_interaction_rule_model!(id)
          unless Domain::Shared::Policies::InteractionRulePolicy.edit_allowed?(user, is_reference: rule.is_reference, user_id: rule.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          rule
        end

        def find_model(id)
          find_interaction_rule_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::InteractionRulePolicy.normalize_attrs_for_create(user, attrs)
          rule = ::InteractionRule.new(h)
          raise StandardError, rule.errors.full_messages.join(", ") unless rule.save

          rule
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
          raise StandardError, rule.errors.full_messages.join(", ") unless rule.update(normalized)

          rule.reload
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
