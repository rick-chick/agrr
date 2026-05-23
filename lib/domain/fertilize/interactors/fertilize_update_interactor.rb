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
          current = nil
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          current = @gateway.find_by_id(input_dto.fertilize_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)

          attrs = {}

          # is_referenceをbooleanに変換してチェック
          if Domain::Shared.present?(input_dto.is_reference)
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(input_dto.is_reference) || false
            unless Domain::Shared::Policies::ReferencableResourcePolicy.reference_flag_change_allowed?(user, requested: is_reference, current: current.is_reference)
              raise Domain::Shared::Exceptions::RecordInvalid.new(@translator.t("fertilizes.flash.reference_flag_admin_only"))
            end
            attrs[:is_reference] = is_reference
          end

          attrs[:name] = input_dto.name if Domain::Shared.present?(input_dto.name)
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
          fertilize_entity = @gateway.update_for_user(user, input_dto.fertilize_id, normalized)

          @output_port.on_success(fertilize_entity)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound, Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(
            Domain::Fertilize::Dtos::FertilizeUpdateFailure.new(
              message: e.message,
              master_form_snapshot: current ? snapshot_from_entity(current) : nil
            )
          )
        end

        private

        def snapshot_from_entity(entity)
          Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot.new(
            attributes: {
              name: entity.name, n: entity.n, p: entity.p, k: entity.k,
              description: entity.description, package_size: entity.package_size,
              is_reference: entity.is_reference, region: entity.region, user_id: entity.user_id
            },
            new_record: false,
            id: entity.id,
            error_messages: []
          )
        end
      end
    end
  end
end
