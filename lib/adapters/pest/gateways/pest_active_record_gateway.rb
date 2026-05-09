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

        def find_authorized_model_for_view(user, id, access_filter:)
          pest = find_pest_model!(id)
          unless access_filter.view_allows?(is_reference: pest.is_reference, record_user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pest
        end

        def find_authorized_model_for_edit(user, id, access_filter:)
          pest = find_pest_model!(id)
          unless access_filter.edit_allows?(is_reference: pest.is_reference, record_user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          pest
        end

        def authorized_pest_detail_output(user, id, access_filter:)
          pest = ::Pest.includes(:pest_temperature_profile, :pest_thermal_requirement, :pest_control_methods, :crops).find(id)
          unless access_filter.view_allows?(is_reference: pest.is_reference, record_user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          Adapters::Pest::Mappers::PestMapper.detail_output_dto_from_record(pest)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end

        def find_authorized_for_edit(user, id, access_filter:)
          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(find_authorized_model_for_edit(user, id, access_filter: access_filter))
        end

        def find_authorized_pest_loaded_bundle!(user, id, for_edit:, access_filter:)
          pest = if for_edit
                   find_authorized_model_for_edit(user, id, access_filter: access_filter)
                 else
                   find_authorized_model_for_view(user, id, access_filter: access_filter)
                 end
          Domain::Pest::Ports::PestHtmlAuthorizedPestLoad.new(
            pest_entity: Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest),
            persisted_pest: pest
          )
        end

        def create_for_user(user, attrs)
          pest = ::Pest.new(attrs.to_h.symbolize_keys)
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless pest.save

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest)
        end

        def update_for_user(user, id, attrs, access_filter:)
          pest = find_pest_model!(id)
          unless access_filter.edit_allows?(is_reference: pest.is_reference, record_user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end

          success = pest.update(attrs.to_h.symbolize_keys)
          if success
            success = pest.pest_temperature_profile&.valid? != false &&
                     pest.pest_thermal_requirement&.valid? != false &&
                     pest.pest_control_methods.all? { |method| method.valid? }
          end
          raise Domain::Shared::Exceptions::RecordInvalid, pest.errors.full_messages.join(", ") unless success

          Adapters::Pest::Mappers::PestMapper.pest_entity_from_record(pest.reload)
        end

        def soft_destroy_with_undo(user:, pest_id:, auto_hide_after: 5000, translator:, access_filter:)
          pest = find_pest_model!(pest_id)
          unless access_filter.edit_allows?(is_reference: pest.is_reference, record_user_id: pest.user_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied
          end
          if pest.pesticides.any?
            return { success: false, error_dto: Domain::Shared::Dtos::ErrorDto.new(translator.t("pests.flash.cannot_delete_in_use")) }
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
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound
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

        def link_pest_to_crop(crop_id:, pest_id:, crop_access_filter:)
          crop = crop_authorized_for_nested_edit(crop_id, crop_access_filter)
          pest = ::Pest.find_by(id: pest_id)
          return :missing unless crop && pest
          return :already_linked if crop.pests.include?(pest)

          crop.pests << pest
          :linked
        end

        def create_pest_for_crop(user:, crop_id:, pest_attrs:, crop_access_filter:)
          crop = crop_authorized_for_nested_edit(crop_id, crop_access_filter)
          attrs = pest_attrs.to_h.symbolize_keys
          pest = ::Pest.new(attrs)

          unless crop
            return { status: :invalid, pest_record: pest, unassociated_pest_entities: [] }
          end

          if pest.save
            crop.pests << pest unless crop.pests.include?(pest)
            return { status: :created, pest_record: pest, unassociated_pest_entities: [] }
          end

          available_entities = list_selectable_pest_entities_recent_first(user)
          crop_pests_ids = crop.pest_ids
          unassociated = available_entities.reject { |e| crop_pests_ids.include?(e.id) }
          { status: :invalid, pest_record: pest, unassociated_pest_entities: unassociated }
        end

        def update_pest_for_crop(user:, crop_id:, pest_id:, pest_attrs:, crop_access_filter:)
          crop = crop_authorized_for_nested_edit(crop_id, crop_access_filter)
          return { status: :crop_missing, pest_record: nil } unless crop

          pest = crop.pests.find_by(id: pest_id)
          return { status: :pest_missing, pest_record: nil } unless pest

          attrs = pest_attrs.to_h.symbolize_keys
          if pest.update(attrs)
            { status: :updated, pest_record: pest }
          else
            { status: :invalid, pest_record: pest }
          end
        end

        def find_pest_in_crop(crop_id:, pest_id:, crop_access_filter:)
          crop = crop_authorized_for_nested_edit(crop_id, crop_access_filter)
          return { status: :not_found, pest_record: nil } unless crop

          pest = crop.pests.find_by(id: pest_id)
          return { status: :not_found, pest_record: nil } unless pest

          { status: :found, pest_record: pest }
        end

        def prepare_crop_nested_pest_for_edit_form!(pest_record)
          ensure_pest_control_method_row_for_form!(pest_record)
        end

        def prepare_top_level_pest_for_edit_form!(pest_record)
          ensure_pest_control_method_row_for_form!(pest_record)
        end

        def normalize_crop_ids_for_pest_form(pest_model:, raw_crop_ids:, user:)
          allowed_ids = Domain::Shared::PestCropAssociationAccess.accessible_crops_scope(pest_model, user: user).pluck(:id)
          Array(raw_crop_ids).compact.reject(&:blank?).map(&:to_i).uniq & allowed_ids
        end

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

        def find_user_owned_non_reference_pest_record_by_name(user_id:, name:)
          return nil if name.blank?

          ::Pest.find_by(name: name, is_reference: false, user_id: user_id)
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

        private

        def crop_authorized_for_nested_edit(crop_id, crop_access_filter)
          crop = ::Crop.find_by(id: crop_id)
          return nil unless crop
          # 参照作物は `CropLoadAuthorizedForCropPestsInteractor` と同条件（誰でもネスト害虫画面・関連付け可）
          return crop if crop.is_reference
          return nil unless crop_access_filter.edit_allows?(is_reference: crop.is_reference, record_user_id: crop.user_id)

          crop
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
