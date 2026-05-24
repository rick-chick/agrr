# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationUpdateInteractor
        include Concerns::PlanFieldCultivationAuthorization

        def initialize(output_port:, gateway:, user_id: nil, user_lookup: nil, translator: nil)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
          @translator = translator
        end

        def call(input_dto)
          if @user_id.present?
            user = @user_lookup.find(@user_id)
            assert_field_cultivation_plan_access!(user, @gateway, input_dto.field_cultivation_id, for_edit: true)
          else
            assert_public_field_cultivation_plan_access!(@gateway, input_dto.field_cultivation_id)
          end

          cultivation_days = nil
          if input_dto.public_plan?
            start_d = parse_date(input_dto.start_date)
            end_d = parse_date(input_dto.completion_date)
            cultivation_days = (end_d - start_d).to_i + 1 if start_d && end_d
          end

          dto = @gateway.update_field_cultivation_schedule(
            field_cultivation_id: input_dto.field_cultivation_id,
            start_date: input_dto.start_date,
            completion_date: input_dto.completion_date,
            cultivation_days: cultivation_days
          )

          if input_dto.public_plan?
            message = public_plan_update_message
            dto = Domain::FieldCultivation::Dtos::FieldCultivationApiUpdateOutput.new(
              field_cultivation_id: dto.field_cultivation_id,
              start_date: dto.start_date,
              completion_date: dto.completion_date,
              cultivation_days: dto.cultivation_days,
              message: message
            )
          end

          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(e)
        end

        private

        def parse_date(value)
          return value if value.is_a?(Date)

          Date.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def public_plan_update_message
          return "栽培期間を更新しました" unless @translator

          key = "field_cultivations.update.success"
          translated = @translator.t(key)
          translated == key ? "栽培期間を更新しました" : translated
        rescue StandardError
          "栽培期間を更新しました"
        end
      end
    end
  end
end
