# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeCreateInteractor < Domain::Fertilize::Ports::FertilizeCreateInputPort
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

          # is_referenceをbooleanに変換（"0", "false", ""はfalseとして扱う）
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
          unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_assignment_allowed?(user, is_reference: is_reference)
            raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("fertilizes.flash.reference_only_admin"))
          end

          attrs = Domain::Shared::Policies::FertilizePolicy.normalize_attrs_for_create(user, {
            name: input_dto.name,
            n: input_dto.n,
            p: input_dto.p,
            k: input_dto.k,
            description: input_dto.description,
            package_size: input_dto.package_size,
            region: input_dto.region,
            is_reference: is_reference
          })
          fertilize_entity = @gateway.create_for_user(user, attrs)

          @output_port.on_success(fertilize_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          if attrs
            snapshot = @gateway.fertilize_master_form_snapshot_after_create_failure!(user: user, attributes: attrs)
            @output_port.on_failure(Domain::Fertilize::Dtos::FertilizeCreateFailure.new(message: e.message, master_form_snapshot: snapshot))
          else
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
          end
        end
      end
    end
  end
end
