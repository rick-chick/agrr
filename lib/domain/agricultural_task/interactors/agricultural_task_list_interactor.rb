# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::AgriculturalTask::Dtos::AgriculturalTaskListInputDto.new(is_admin: false)

          user = User.find(@user_id)

          # コントローラの既存ロジックを移行
          scope = if input_dto.is_admin
                    agricultural_tasks_for_admin(input_dto.filter, ::AgriculturalTask.all)
                  else
                    Domain::Shared::Policies::AgriculturalTaskPolicy.visible_scope(::AgriculturalTask, user)
                  end

          scope = apply_search(scope, input_dto.query) if input_dto.query.present?
          scope = scope.recent

          tasks = @gateway.list
          filtered_tasks = tasks.select { |task_entity| scope.exists?(task_entity.id) }

          @output_port.on_success(filtered_tasks)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end

        private

        def agricultural_tasks_for_admin(filter, base_scope = nil)
          base_scope ||= ::AgriculturalTask.all
          case filter
          when 'reference'
            base_scope.where(is_reference: true)
          when 'all'
            base_scope.where(id: Domain::Shared::Policies::AgriculturalTaskPolicy.visible_scope(::AgriculturalTask, User.find(@user_id)).pluck(:id))
          else
            base_scope.where(id: Domain::Shared::Policies::AgriculturalTaskPolicy.user_owned_non_reference_scope(::AgriculturalTask, User.find(@user_id)).pluck(:id))
          end
        end

        def apply_search(scope, term)
          return scope if term.blank?

          sanitized = ActiveRecord::Base.sanitize_sql_like(term)
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
