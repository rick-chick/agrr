# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # AI 害虫 API: affected_crops を解決し、認可済み crop_id のみ Gateway に永続化する。
      class PestAssociateAffectedCropsInteractor
        def initialize(user_id:, user_lookup:, pest_gateway:, crop_gateway:, crop_pest_gateway:, logger:)
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
          @crop_gateway = crop_gateway
          @crop_pest_gateway = crop_pest_gateway
          @logger = logger
          @association_sync = Services::CropPestAssociationSync.new(crop_pest_gateway: crop_pest_gateway)
        end

        # @param affected_crops [Array<Hash>]
        # @return [Integer] 新規に紐づけた件数
        def call(pest_id:, affected_crops:)
          @logger.info "🔗 [AI Pest] associate_affected_crops called with: #{affected_crops.inspect}"

          user = @user_lookup.find(@user_id)
          pest = @pest_gateway.find_by_id(pest_id)

          crop_ids = Domain::Pest::Mappers::PestAiAffectedCropsPayloadMapper.extract_crop_ids(affected_crops)
          @logger.info "🔗 [AI Pest] Extracted crop IDs: #{crop_ids.inspect}"

          if crop_ids.empty?
            crop_ids = resolve_crop_ids_from_names(
              Domain::Pest::Mappers::PestAiAffectedCropsPayloadMapper.extract_crop_names(affected_crops),
              user: user
            )
            @logger.info "🔗 [AI Pest] Crop IDs after name fallback: #{crop_ids.inspect}"
          end

          if crop_ids.empty?
            @logger.warn "⚠️  [AI Pest] No crop IDs resolved from affected_crops"
            return 0
          end

          authorized_ids = Domain::Pest::Services::FilterAssociableCropIds.for_ai_affected_crops(
            crop_ids: crop_ids,
            pest: pest,
            user: user,
            crop_gateway: @crop_gateway
          )

          count = @association_sync.add_missing(pest_id: pest_id, crop_ids: authorized_ids)
          @logger.info "✅ [AI Pest] Crop association completed: #{count} crops associated"
          count
        end

        private

        def resolve_crop_ids_from_names(crop_names, user:)
          crop_names.filter_map do |name|
            candidates = @crop_gateway.list_by_name(name: name)
            id = Domain::Crop::Policies::CropResolveByNamePolicy.select_id_for_pest_ai_name_fallback(
              user: user,
              candidates: candidates
            )
            if id
              @logger.info "✅ [AI Pest] Fallback matched crop by name: #{name} -> ID=#{id}"
            else
              @logger.warn "⚠️  [AI Pest] Could not match crop by name: #{name}"
            end
            id
          end.uniq
        end
      end
    end
  end
end
