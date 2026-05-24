# frozen_string_literal: true

module Domain
  module InteractionRule
    module Gateways
      # InteractionRule ドメインの Gateway interface。
      # Adapter 実装は lib/adapters/interaction_rule/gateways/ に存在する。
      # 実装の生成は CompositionRoot のみ。
      class InteractionRuleGateway
        def find_by_id(rule_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(rule_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

        # @return [Array<Domain::InteractionRule::Entities::InteractionRuleEntity>]
        def list_by_cultivation_plan_id(cultivation_plan_id:)
          raise NotImplementedError, "Subclasses must implement list_by_cultivation_plan_id"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, rule_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end
      end
    end
  end
end
