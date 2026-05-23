# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideCreateInteractor < Domain::Pesticide::Ports::PesticideCreateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          attrs = nil
          user = @user_lookup.find(@user_id)
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_assignment_allowed?(user, is_reference: is_reference)
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("pesticides.flash.reference_only_admin"))
          end

          attrs = {
            name: input_dto.name,
            active_ingredient: input_dto.active_ingredient,
            description: input_dto.description,
            crop_id: input_dto.crop_id,
            pest_id: input_dto.pest_id,
            region: input_dto.region,
            is_reference: is_reference
          }.compact
          attrs = Domain::Shared::Policies::PesticidePolicy.normalize_attrs_for_create(user, attrs)
          pesticide_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(pesticide_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          if attrs
            bundle = @gateway.pesticide_html_master_form_bundle(
              assign_attributes: input_dto.assign_attributes_for_form || {},
              crop_list_filter: Domain::Shared::Policies::CropPolicy.index_list_filter(user),
              pest_list_filter: Domain::Shared::Policies::PestPolicy.index_list_filter(user)
            )
            @output_port.on_failure(Domain::Pesticide::Dtos::PesticideHtmlMasterFormFailure.new(message: e.message, bundle: bundle))
          else
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          end
        end
      end
    end
  end
end
