# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskListInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(input_dto = nil)
          input_dto ||= Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.new(is_admin: false)

          user = @user_lookup.find(@user_id)

          # コントローラの既存ロジックを移行
          scope = if input_dto.is_admin
                    agricultural_tasks_for_admin(input_dto.filter, user, @gateway.all_records_relation)
          else
                    @gateway.visible_records(user)
          end

          scope = apply_search(scope, input_dto.query) if Domain::Shared::ValidationHelpers.present?(input_dto.query)
          scope = scope.recent

          filtered_tasks = @gateway.list_from_relation(scope)

          @output_port.on_success(filtered_tasks)
        rescue ActiveRecord::RecordNotFound, Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end

        private

        def agricultural_tasks_for_admin(filter, user, base_scope = nil)
          base_scope ||= @gateway.all_records_relation
          case filter
          when "reference"
            base_scope.where(is_reference: true)
          when "all"
            base_scope.merge(@gateway.visible_records(user))
          else
            base_scope.merge(@gateway.user_owned_non_reference_records(user))
          end
        end

        def apply_search(scope, term)
          return scope if Domain::Shared::ValidationHelpers.blank?(term)

          sanitized = Domain::Shared::SqlLike.sanitize(term)
          query = "%#{sanitized}%"
          scope.where(
            "agricultural_tasks.name LIKE :query OR COALESCE(agricultural_tasks.description, '') LIKE :query",
            query: query
          )
        end
      end
    end
  end
end
