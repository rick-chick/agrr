# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeUpdateInteractor < Domain::Fertilize::Ports::FertilizeUpdateInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(input_dto)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          current = @gateway.find_authorized_for_edit(user, input_dto.fertilize_id, access_filter: access_filter)

          attrs = {}

          # is_referenceをbooleanに変換してチェック
          if Domain::Shared::ValidationHelpers.present?(input_dto.is_reference)
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
            if is_reference != current.is_reference && !user.admin?
              raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("fertilizes.flash.reference_flag_admin_only"))
            end
            attrs[:is_reference] = is_reference
          end

          attrs[:name] = input_dto.name if Domain::Shared::ValidationHelpers.present?(input_dto.name)
          attrs[:n] = input_dto.n if !input_dto.n.nil?
          attrs[:p] = input_dto.p if !input_dto.p.nil?
          attrs[:k] = input_dto.k if !input_dto.k.nil?
          attrs[:description] = input_dto.description if !input_dto.description.nil?
          attrs[:package_size] = input_dto.package_size if !input_dto.package_size.nil?
          attrs[:region] = input_dto.region if !input_dto.region.nil?

          normalized = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_update(
            user,
            { is_reference: !!current.is_reference },
            attrs
          )
          fertilize_entity = @gateway.update_for_user(user, input_dto.fertilize_id, normalized, access_filter: access_filter)

          @output_port.on_success(fertilize_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          form_fertilize = load_form_fertilize_for_failure(user, input_dto, access_filter)
          @output_port.on_failure(
            Domain::Fertilize::Dtos::FertilizeUpdateFailureDto.new(message: e.message, form_fertilize: form_fertilize)
          )
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          form_fertilize = load_form_fertilize_for_failure(user, input_dto, access_filter)
          @output_port.on_failure(
            Domain::Fertilize::Dtos::FertilizeUpdateFailureDto.new(message: e.message, form_fertilize: form_fertilize)
          )
        end

        private

        def load_form_fertilize_for_failure(user, input_dto, access_filter)
          return nil unless user && access_filter && !Domain::Shared::ValidationHelpers.blank?(input_dto.fertilize_id)

          fid = input_dto.fertilize_id.to_i
          begin
            bundle = @gateway.find_authorized_fertilize_loaded_bundle!(user, fid, for_edit: true, access_filter: access_filter)
            return bundle.persisted_fertilize
          rescue Domain::Shared::Policies::PolicyPermissionDenied,
                 Domain::Shared::Exceptions::RecordNotFound,
                 Domain::Shared::Exceptions::RecordInvalid
            # fall through to model_for_edit
          end

          begin
            @gateway.find_authorized_model_for_edit(user, fid, access_filter: access_filter)
          rescue Domain::Shared::Policies::PolicyPermissionDenied,
                 Domain::Shared::Exceptions::RecordNotFound,
                 Domain::Shared::Exceptions::RecordInvalid
            nil
          end
        end
      end
    end
  end
end
