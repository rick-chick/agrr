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

        def destroy(rule_id)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # agrr 分配用のルール配列（空なら nil）
        def agrr_rules_for_cultivation_plan_id(cultivation_plan_id)
          raise NotImplementedError, "Subclasses must implement agrr_rules_for_cultivation_plan_id"
        end

        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def find_authorized_for_view(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id, access_filter:)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs, access_filter:)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_delete_with_undo(user:, rule_id:, auto_hide_after:, translator:, access_filter:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end
      end
    end
  end
end
