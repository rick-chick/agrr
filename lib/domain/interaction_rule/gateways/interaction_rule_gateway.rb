# frozen_string_literal: true

module Domain
  module InteractionRule
    module Gateways
      class InteractionRuleGateway
        # @param scope [ActiveRecord::Relation, nil] 表示対象スコープ。nil の場合は全件
        def list(scope = nil)
          raise NotImplementedError, "Subclasses must implement list"
        end

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
      end
    end
  end
end
