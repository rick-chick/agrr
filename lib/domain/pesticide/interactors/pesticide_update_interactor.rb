# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideUpdateInteractor < Domain::Pesticide::Ports::PesticideUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          current = @gateway.find_authorized_for_edit(user, input_dto.pesticide_id)

          unless input_dto.is_reference.nil?
            requested = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference)
            requested = false if requested.nil?
            if requested != !!current.is_reference && !user.admin?
              raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("pesticides.flash.reference_flag_admin_only"))
            end
          end

          attrs = {}
          attrs[:name] = input_dto.name unless input_dto.name.nil?
          attrs[:active_ingredient] = input_dto.active_ingredient if !input_dto.active_ingredient.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:crop_id] = input_dto.crop_id if !input_dto.crop_id.nil?
          attrs[:pest_id] = input_dto.pest_id if !input_dto.pest_id.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?
          attrs[:is_reference] = input_dto.is_reference if !input_dto.is_reference.nil?

          normalized = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_update(
            user,
            { is_reference: !!current.is_reference },
            attrs
          )
          pesticide_entity = @gateway.update_for_user(user, input_dto.pesticide_id, normalized)

          @output_port.on_success(pesticide_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
