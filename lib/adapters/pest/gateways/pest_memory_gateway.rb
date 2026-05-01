# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestMemoryGateway < Domain::Pest::Gateways::PestGateway
        def list(query = nil)
          if query.is_a?(Domain::Shared::Dtos::QueryDto)
            scope = build_scope_from_query(query)
          else
            scope = query || ::Pest.all
          end
          scope.map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
        end

        def list_index_for_user(user)
          list(index_scope_for_user(user))
        end

        def selectable_pest_ids(user)
          selectable_scope(user).pluck(:id)
        end

        def pest_selectable_by_user?(user, pest_id)
          selectable_scope(user).exists?(id: pest_id)
        end

        def list_selectable_pest_entities_recent_first(user)
          selectable_scope(user).recent.map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
        end

        def list_pests_for_crop_filtered(crop_id:, pest_ids:, order: :recent_first)
          return [] if pest_ids.blank?

          base = ::Pest.joins(:crop_pests).where(crop_pests: { crop_id: crop_id }).where(id: pest_ids)
          ordered = case order.to_sym
                    when :recent_first then base.order(created_at: :desc)
                    when :id_asc then base.order(:id)
                    else base.order(:id)
                    end
          ordered.map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
        end

        def find_authorized_model_for_view(user, id)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.view_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pest
        end

        def find_authorized_model_for_edit(user, id)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pest
        end

        def find_authorized_for_view(user, id)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(find_authorized_model_for_view(user, id))
        end

        def find_authorized_for_edit(user, id)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(find_authorized_model_for_edit(user, id))
        end

        def find_model(id)
          find_pest_model!(id)
        end

        def create_for_user(user, attrs)
          h = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_create(user, attrs)
          pest = ::Pest.new(h)
          raise StandardError, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update_for_user(user, id, attrs)
          pest = find_pest_model!(id)
          unless Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          normalized = Domain::Shared::Policies::PestPolicy.normalize_attrs_for_update(
            user,
            pest.attributes.symbolize_keys,
            attrs
          )
          success = pest.update(normalized)
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          raise StandardError, pest.errors.full_messages.join(", ") unless success

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        end

        def soft_destroy_with_undo(user:, pest_id:, auto_hide_after: 5000, translator: nil)
          translator ||= Adapters::Translators::RailsTranslator.new
          pest = find_pest_model!(pest_id)
          unless Domain::Shared::Policies::PestPolicy.edit_allowed?(user, is_reference: pest.is_reference, user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          if pest.pesticides.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("pests.flash.cannot_delete_in_use")) }
          end
          toast_message = translator.t("pests.undo.toast", name: pest.name)
          undo_gw = Domain::DeletionUndo::Gateways::DeletionUndoGateway.default
          event = undo_gw.schedule(
            record: pest,
            actor: user,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(e.message) }
        end

        def find_by_id(pest_id)
          pest = ::Pest.find(pest_id)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        def build_blank_pest_for_form
          pest = ::Pest.new
          pest.build_pest_temperature_profile
          pest.build_pest_thermal_requirement
          pest.pest_control_methods.build
          pest
        end

        def link_pest_to_crop_id(crop_id:, pest_id:)
          crop = ::Crop.find_by(id: crop_id)
          pest = ::Pest.find_by(id: pest_id)
          return :missing unless crop && pest
          return :already_linked if crop.pests.include?(pest)

          crop.pests << pest
          :linked
        end

        def create_pest_for_crop(user:, crop_id:, pest_attrs:, admin:)
          attrs = pest_attrs.to_h.symbolize_keys
          is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attrs[:is_reference]) || false
          if is_reference && !admin
            return { status: :reference_only_admin, pest_record: nil, unassociated_pest_entities: [] }
          end

          pest = ::Pest.new(attrs)
          unless admin
            pest.is_reference = false
            pest.user_id = user.id
          end

          if pest.save
            crop = ::Crop.find_by(id: crop_id)
            crop.pests << pest if crop && !crop.pests.include?(pest)
            return { status: :created, pest_record: pest, unassociated_pest_entities: [] }
          end

          available_entities = list_selectable_pest_entities_recent_first(user)
          crop_pests_ids = crop_id ? (::Crop.find_by(id: crop_id)&.pest_ids || []) : []
          unassociated = available_entities.reject { |e| crop_pests_ids.include?(e.id) }
          { status: :invalid, pest_record: pest, unassociated_pest_entities: unassociated }
        end

        def update_pest_for_crop(crop_id:, pest_id:, pest_attrs:, admin:)
          crop = ::Crop.find_by(id: crop_id)
          return { status: :crop_missing, pest_record: nil } unless crop

          pest = crop.pests.find_by(id: pest_id)
          return { status: :pest_missing, pest_record: nil } unless pest

          attrs = pest_attrs.to_h.symbolize_keys
          if attrs.key?(:is_reference) && !admin
            is_reference = Domain::Shared::TypeConverters::BooleanConverter.cast(attrs[:is_reference]) || false
            if is_reference != pest.is_reference
              return { status: :reference_flag_denied, pest_record: pest }
            end
          end

          if pest.update(attrs)
            { status: :updated, pest_record: pest }
          else
            { status: :invalid, pest_record: pest }
          end
        end

        def find_pest_in_crop(crop_id:, pest_id:)
          crop = ::Crop.find_by(id: crop_id)
          return { status: :crop_missing, pest_record: nil } unless crop

          pest = crop.pests.find_by(id: pest_id)
          return { status: :not_found, pest_record: nil } unless pest

          { status: :found, pest_record: pest }
        end

        def associate_crops_with_pest_id(pest_id:, crop_ids:, user:)
          ::PestCropAssociationService.associate_crops_by_pest_id(pest_id, crop_ids, user: user)
        end

        def update_pest_crop_associations(pest_id:, crop_ids:, user:)
          ::PestCropAssociationService.update_crop_associations_by_pest_id(pest_id, crop_ids, user: user)
        end

        def create(create_input_dto)
          pest = ::Pest.new(
            name: create_input_dto.name,
            name_scientific: create_input_dto.name_scientific,
            family: create_input_dto.family,
            order: create_input_dto.order,
            description: create_input_dto.description,
            occurrence_season: create_input_dto.occurrence_season,
            region: create_input_dto.region
          )
          raise StandardError, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update(pest_id, update_input_dto)
          pest = ::Pest.find(pest_id)
          attrs = {}
          attrs[:name] = update_input_dto.name if update_input_dto.name.present?
          attrs[:name_scientific] = update_input_dto.name_scientific if !update_input_dto.name_scientific.nil?
          attrs[:family] = update_input_dto.family if !update_input_dto.family.nil?
          attrs[:order] = update_input_dto.order if !update_input_dto.order.nil?
          attrs[:description] = update_input_dto.description if !update_input_dto.description.nil?
          attrs[:occurrence_season] = update_input_dto.occurrence_season if !update_input_dto.occurrence_season.nil?
          attrs[:region] = update_input_dto.region if !update_input_dto.region.nil?

          pest.update(attrs)
          raise StandardError, pest.errors.full_messages.join(", ") if pest.errors.any?

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        private

        def index_scope_for_user(user)
          if user.admin?
            ::Pest.where("is_reference = ? OR user_id = ?", true, user.id)
          else
            ::Pest.where(user_id: user.id, is_reference: false)
          end
        end

        def selectable_scope(user)
          ::Pest.where("is_reference = ? OR user_id = ?", true, user.id)
        end

        def find_pest_model!(id)
          ::Pest.find(id)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def build_scope_from_query(query)
          return ::Pest.all unless query.present?

          ::Pest.all
        end
      end
    end
  end
end
