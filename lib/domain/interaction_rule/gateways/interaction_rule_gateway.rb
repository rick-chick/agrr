# frozen_string_literal: true

module Domain
  module InteractionRule
    module Gateways
      class InteractionRuleGateway
        class << self
          def default
            @default ||= Adapters::InteractionRule::Gateways::InteractionRuleActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        # @param query [Domain::Shared::Dtos::QueryDto, nil] クエリ条件。nil の場合は全件
        def list(query = nil)
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

        # agrr 分配用のルール配列（空なら nil）
        def agrr_rules_for_cultivation_plan(cultivation_plan)
          raise NotImplementedError, "Subclasses must implement agrr_rules_for_cultivation_plan"
        end

        def visible_records(user)
          raise NotImplementedError, "Subclasses must implement visible_records"
        end

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        def soft_destroy_with_undo(user:, rule_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
