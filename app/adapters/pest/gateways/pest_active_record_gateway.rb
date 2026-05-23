# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestActiveRecordGateway < Domain::Pest::Gateways::PestGateway
        def initialize(deletion_undo_gateway:)
          @deletion_undo_gateway = deletion_undo_gateway
        end

        def list_index_for_filter(filter)
          index_relation_for_filter(filter).map { |record| Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record) }
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

        def authorized_pest_detail_output(id)
          pest = ::Pest.includes(:pest_temperature_profile, :pest_thermal_requirement, :pest_control_methods, :crops).find(id)
          Adapters::Pest::Mappers::PestMapper.detail_output_dto_from_record(pest)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_pest_loaded_bundle!(id)
          record = find_pest_model!(id)
          ensure_pest_control_method_row_for_form!(record)
          Domain::Pest::Dtos::PestAuthorizedLoad.new(
            pest_master_edit_payload: Adapters::Pest::Mappers::PestMasterEditPayloadMapper.from_record(record)
          )
        end

        def create_for_user(user, attrs)
          pest = ::Pest.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update_for_user(_user, id, attrs)
          pest = find_pest_model!(id)
          success = pest.update(attrs.to_h.symbolize_keys)
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless success

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        end

        def soft_delete_with_undo(user:, pest_id:, auto_hide_after: 5000, translator:)
          pest = find_pest_model!(pest_id)
          if pest.pesticides.any?
            return { success: false, error_dto: Domain::Shared::Dtos::Error.new(translator.t("pests.flash.cannot_delete_in_use")) }
          end
          toast_message = translator.t("pests.undo.toast", name: pest.name)
          undo_gw = @deletion_undo_gateway
          event = undo_gw.schedule(
            resource_type: pest.class.name,
            resource_id: pest.id,
            actor_id: user.id,
            toast_message: toast_message,
            auto_hide_after: auto_hide_after
          )
          { success: true, undo_entity: event }
        rescue Domain::Shared::Exceptions::RecordNotFound
          raise
        rescue StandardError => e
          { success: false, error_dto: Domain::Shared::Dtos::Error.new(e.message) }
        end

        def find_by_id(pest_id)
          pest = ::Pest.find(pest_id)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        def pest_master_form_crop_selection_bundle!(user:, master_edit_payload:, request_crop_ids: :use_payload_associations)
          pest_like = Domain::Pest::Dtos::PestCropAssociationPestInput.from_master_edit_payload(master_edit_payload)
          raw_base =
            if request_crop_ids == :use_payload_associations
              master_edit_payload.associated_crop_ids
            else
              Array(request_crop_ids)
            end

          relation = accessible_crops_relation_for_pest_association(
            is_reference: pest_like.is_reference?,
            owner_user_id: pest_like.user_id,
            region: pest_like.region,
            user: user
          )
          accessible_records =
            relation.to_a.select do |crop|
              Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest_like, user: user)
            end
          accessible_crops =
            accessible_records.map do |crop|
              Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
            end
          allowed_ids = accessible_crops.map(&:id)
          normalized_selected = Array(raw_base).map(&:to_i).uniq & allowed_ids
          crop_cards =
            Domain::Crop::Mappers::MasterFormCropSelectionCardsMapper.build(
              accessible_crops: accessible_crops,
              selected_ids: normalized_selected
            )

          Domain::Pest::Dtos::PestMasterFormCropSelectionBundle.new(
            selected_crop_ids: normalized_selected,
            crop_cards: crop_cards
          )
        end

        def link_pest_to_crop(crop_id:, pest_id:, user:, crop_access_filter: nil)
          crop = find_crop_model(crop_id)
          pest = ::Pest.find_by(id: pest_id)
          return :missing unless crop && pest
          return :already_linked if crop.pests.include?(pest)

          unless Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: user)
            return :forbidden
          end

          crop.pests << pest
          :linked
        end

        def create_pest_for_crop(user:, crop_id:, pest_attrs:, crop_access_filter: nil)
          crop = find_crop_model(crop_id)
          attrs = pest_attrs.to_h.symbolize_keys
          pest = ::Pest.new(attrs)

          unless crop
            return Domain::Pest::Dtos::PestMutationOutput.new(
              status: :invalid,
              crop_nest_snapshot: pest_crop_nest_snapshot_from(pest),
              unassociated_pest_entities: []
            )
          end

          if pest.save
            crop.pests << pest unless crop.pests.include?(pest)
            return Domain::Pest::Dtos::PestMutationOutput.new(
              status: :created,
              pest_entity: Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest),
              crop_nest_snapshot: pest_crop_nest_snapshot_from(pest),
              unassociated_pest_entities: []
            )
          end

          available_entities = list_selectable_pest_entities_recent_first(user)
          crop_pests_ids = crop.pest_ids
          unassociated = available_entities.reject { |e| crop_pests_ids.include?(e.id) }
          Domain::Pest::Dtos::PestMutationOutput.new(
            status: :invalid,
            crop_nest_snapshot: pest_crop_nest_snapshot_from(pest),
            unassociated_pest_entities: unassociated
          )
        end

        def update_pest_for_crop(user:, crop_id:, pest_id:, pest_attrs:, crop_access_filter: nil)
          crop = find_crop_model(crop_id)
          unless crop
            return Domain::Pest::Dtos::PestMutationOutput.new(status: :crop_missing)
          end

          pest = crop.pests.includes(:pest_temperature_profile, :pest_thermal_requirement, :pest_control_methods).find_by(id: pest_id)
          unless pest
            return Domain::Pest::Dtos::PestMutationOutput.new(status: :pest_missing)
          end

          attrs = pest_attrs.to_h.symbolize_keys
          if pest.update(attrs)
            Domain::Pest::Dtos::PestMutationOutput.new(
              status: :updated,
              crop_nest_snapshot: pest_crop_nest_snapshot_from(pest)
            )
          else
            Domain::Pest::Dtos::PestMutationOutput.new(
              status: :invalid,
              crop_nest_snapshot: pest_crop_nest_snapshot_from(pest)
            )
          end
        end

        def find_pest_in_crop(crop_id:, pest_id:, crop_access_filter: nil, for_edit_form: false)
          crop = find_crop_model(crop_id)
          unless crop
            return Domain::Pest::Dtos::PestMutationOutput.new(status: :not_found)
          end

          pest = crop.pests.includes(:pest_temperature_profile, :pest_thermal_requirement, :pest_control_methods).find_by(id: pest_id)
          unless pest
            return Domain::Pest::Dtos::PestMutationOutput.new(status: :not_found)
          end

          Domain::Pest::Dtos::PestMutationOutput.new(
            status: :found,
            crop_nest_snapshot: pest_crop_nest_snapshot_from(pest, ensure_blank_control_method: for_edit_form)
          )
        end

        private

        # {Domain::Shared::PestCropAssociationAccess} と整合する作物 Relation（アダプター内永続のみ）
        def accessible_crops_relation_for_pest_association(is_reference:, owner_user_id:, region:, user:)
          scope =
            if is_reference
              ::Crop.where(is_reference: true)
            else
              owner_id = owner_user_id || user&.id
              # ユーザー害虫: 同じ所有者の非参照作物 + 参照作物すべて
              ::Crop.where("is_reference = ? OR (is_reference = ? AND user_id = ?)", true, false, owner_id)
            end

          scope = scope.where(region: region) if region.present?
          scope.order(:name)
        end

        public

        def associate_crops_with_pest_id(pest_id:, crop_ids:, user:)
          pest = ::Pest.find(pest_id)
          associate_crops_for_pest_record(pest, crop_ids, user: user)
        end

        def update_pest_crop_associations(pest_id:, crop_ids:, user:)
          pest = ::Pest.find(pest_id)
          new_ids = Array(crop_ids).map(&:to_i).uniq
          current_ids = pest.crop_ids

          to_remove = current_ids - new_ids
          removed_count = 0
          to_remove.each do |crop_id|
            crop = ::Crop.find_by(id: crop_id)
            next unless crop

            pest.crops.delete(crop)
            removed_count += 1
          end

          to_add = new_ids - current_ids
          added_count = associate_crops_for_pest_record(pest, to_add, user: user)

          { added: added_count, removed: removed_count }
        end

        def associate_affected_crops_for_ai_pest(pest_id:, affected_crops:, user:, logger:)
          logger.info "🔗 [AI Pest] associate_affected_crops_for_ai_pest called with: #{affected_crops.inspect}"

          crop_ids = extract_crop_ids_from_ai_payload(affected_crops)
          logger.info "🔗 [AI Pest] Extracted crop IDs: #{crop_ids.inspect}"
          logger.info "🔗 [AI Pest] Current user: #{user&.id || "nil"}, is_admin?: #{user.respond_to?(:admin?) && user.admin?}"

          if crop_ids.empty?
            crop_ids = crop_ids_from_ai_names_fallback(affected_crops, user: user, logger: logger)
            crop_ids.uniq!
            logger.info "🔗 [AI Pest] Crop IDs after fallback: #{crop_ids.inspect}"
          end

          if crop_ids.empty?
            logger.warn "⚠️  [AI Pest] No crop IDs extracted from affected_crops"
            return 0
          end

          pest = ::Pest.find_by(id: pest_id)
          unless pest
            logger.warn "⚠️  [AI Pest] Pest not found: ID=#{pest_id}"
            return 0
          end

          associated_count = 0
          begin
            crop_ids.each do |crop_id|
              crop = ::Crop.find_by(id: crop_id)
              unless crop
                logger.warn "⚠️  [AI Pest] Crop not found: ID=#{crop_id}"
                next
              end

              logger.info "🔗 [AI Pest] Processing crop: #{crop.name} (ID: #{crop.id}, is_reference: #{crop.is_reference}, user_id: #{crop.user_id})"

              can_access = ai_pest_crop_accessible?(crop, pest, user: user)

              logger.info "🔗 [AI Pest] Can access crop #{crop.name}? #{can_access}"

              if can_access
                if pest.crops.include?(crop)
                  logger.info "ℹ️  [AI Pest] Crop already associated: #{crop.name}"
                else
                  pest.crops << crop
                  associated_count += 1
                  logger.info "✅ [AI Pest] Associated crop: #{crop.name} (ID: #{crop.id})"
                end
              else
                logger.warn "⚠️  [AI Pest] Cannot access crop: #{crop.name} (user_id: #{crop.user_id}, current_user: #{user&.id})"
              end
            end

            logger.info "✅ [AI Pest] Crop association completed: #{associated_count} crops associated"
          rescue ActiveRecord::ActiveRecordError => e
            logger.error "❌ [AI Pest] Failed to associate crops: #{e.message}"
            logger.error "❌ [AI Pest] Backtrace: #{e.backtrace.first(5).join("\n")}"
          end

          associated_count
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
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless pest.save

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
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") if pest.errors.any?

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pest not found"
        end

        def find_by_name(user_id:, name:)
          return nil if name.blank?

          record = ::Pest.find_by(name: name, is_reference: false, user_id: user_id)
          return nil unless record

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(record)
        end

        def pest_ids_linked_to_crop(crop_id:)
          ::CropPest.where(crop_id: crop_id).pluck(:pest_id)
        end

        def unlink_pest_from_crop_for_masters(user:, crop_id:, pest_id:)
          crop = ::Crop.user_owned.where(user_id: user.id).find_by(id: crop_id)
          return :crop_not_found unless crop

          pest = ::Pest.find_by(id: pest_id)
          return :pest_not_found unless pest

          return :not_associated unless crop.pests.include?(pest)

          crop.pests.delete(pest)
          :ok
        end

        def find_crop_entity_by_id(crop_id)
          crop = find_crop_model(crop_id)
          return nil unless crop

          Adapters::Crop::Mappers::CropMapper.crop_entity_from_record(crop)
        end

        private

        def find_crop_model(crop_id)
          ::Crop.find_by(id: crop_id)
        end

        def associate_crops_for_pest_record(pest, crop_ids, user:)
          associated_count = 0
          Array(crop_ids).each do |crop_id|
            crop = ::Crop.find_by(id: crop_id)
            next unless crop
            next unless Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: user)
            next if pest.crops.include?(crop)

            pest.crops << crop
            associated_count += 1
          end
          associated_count
        end

        def ensure_pest_control_method_row_for_form!(pest_record)
          pest_record.pest_control_methods.build if pest_record.pest_control_methods.empty?
          pest_record
        end

        def pest_crop_nest_snapshot_from(pest, ensure_blank_control_method: false)
          tp = pest.pest_temperature_profile
          temperature_profile_row = tp && { id: tp.id, base_temperature: tp.base_temperature, max_temperature: tp.max_temperature }
          tr = pest.pest_thermal_requirement
          thermal_requirement_row = tr && { id: tr.id, required_gdd: tr.required_gdd, first_generation_gdd: tr.first_generation_gdd }
          control_method_rows = pest.pest_control_methods.sort_by(&:id).map do |m|
            { id: m.id, method_type: m.method_type, method_name: m.method_name, description: m.description, timing_hint: m.timing_hint }
          end
          error_messages = {}
          pest.errors.each do |error|
            attr = error.attribute
            (error_messages[attr] ||= []) << error.message
          end
          if ensure_blank_control_method && control_method_rows.empty?
            control_method_rows = [ { id: nil, method_type: nil, method_name: nil, description: nil, timing_hint: nil } ]
          end
          Domain::Pest::Dtos::PestCropNestSnapshot.new(
            id: pest.id, user_id: pest.user_id, name: pest.name, name_scientific: pest.name_scientific,
            family: pest.family, order: pest.order, description: pest.description,
            occurrence_season: pest.occurrence_season, region: pest.region, is_reference: pest.is_reference,
            created_at: pest.created_at, updated_at: pest.updated_at,
            temperature_profile_row: temperature_profile_row, thermal_requirement_row: thermal_requirement_row,
            control_method_rows: control_method_rows, error_messages_by_attribute: error_messages
          )
        end

        def extract_crop_ids_from_ai_payload(affected_crops)
          affected_crops.map do |c|
            if c.is_a?(Hash)
              c["crop_id"] || c[:crop_id] || c["crop_id".to_sym] || c[:'crop_id']
            elsif c.respond_to?(:[])
              c["crop_id"] || c[:crop_id] || c["crop_id".to_sym]
            elsif c.respond_to?(:crop_id)
              c.crop_id
            else
              nil
            end
          end.compact.reject(&:blank?).map(&:to_i)
        end

        def crop_ids_from_ai_names_fallback(affected_crops, user:, logger:)
          crop_names = affected_crops.map do |c|
            if c.is_a?(Hash)
              c["crop_name"] || c[:crop_name] || c["crop_name".to_sym] || c[:'crop_name']
            elsif c.respond_to?(:[])
              c["crop_name"] || c[:crop_name] || c["crop_name".to_sym]
            elsif c.respond_to?(:crop_name)
              c.crop_name
            else
              nil
            end
          end.compact.reject(&:blank?).map(&:to_s)

          logger.info "🔗 [AI Pest] Fallback with crop names: #{crop_names.inspect}"

          ids = []
          crop_names.each do |name|
            candidate = ::Crop.reference.find_by(name: name)
            candidate ||= if user
              ::Crop.user_owned.where(user_id: user.id).find_by(name: name)
            else
              nil
            end

            if candidate
              ids << candidate.id
              logger.info "✅ [AI Pest] Fallback matched crop by name: #{name} -> ID=#{candidate.id}"
            else
              logger.warn "⚠️  [AI Pest] Could not match crop by name: #{name}"
            end
          end
          ids
        end

        def ai_pest_crop_accessible?(crop, pest, user:)
          if crop.is_reference
            true
          elsif user.nil? || (user.respond_to?(:anonymous?) && user.anonymous?)
            false
          else
            Domain::Shared::PestCropAssociationAccess.crop_accessible_for_pest?(crop, pest, user: user)
          end
        end

        def index_relation_for_filter(filter)
          case filter.mode
          when :reference_or_owned
            ::Pest.where("is_reference = ? OR user_id = ?", true, filter.user_id)
          when :owned_non_reference
            ::Pest.where(user_id: filter.user_id, is_reference: false)
          else
            raise ArgumentError, "unknown ReferenceIndexListFilter mode: #{filter.mode.inspect}"
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
      end
    end
  end
end
