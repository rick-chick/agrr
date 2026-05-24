# frozen_string_literal: true

module Domain
  module Pest
    module Services
      # crop_pest 関連の差分適用（Interactor 間共有の永続化手順のみ）。
      class CropPestAssociationSync
        def initialize(crop_pest_gateway:)
          @crop_pest_gateway = crop_pest_gateway
        end

        # @return [Integer] 新規に作成した件数
        def add_missing(pest_id:, crop_ids:)
          added = 0
          Array(crop_ids).each do |crop_id|
            next if @crop_pest_gateway.find_by_crop_id_and_pest_id(crop_id: crop_id, pest_id: pest_id)

            @crop_pest_gateway.create(crop_id: crop_id, pest_id: pest_id)
            added += 1
          end
          added
        end

        # @return [Domain::Pest::Dtos::PestCropAssociationSyncResult]
        def replace_all(pest_id:, crop_ids:)
          new_ids = Array(crop_ids).map(&:to_i).uniq
          current_ids = @crop_pest_gateway.list_by_pest_id(pest_id: pest_id)

          removed_count = 0
          (current_ids - new_ids).each do |crop_id|
            removed_count += 1 if @crop_pest_gateway.delete(crop_id: crop_id, pest_id: pest_id)
          end

          added_count = add_missing(pest_id: pest_id, crop_ids: new_ids - current_ids)
          Dtos::PestCropAssociationSyncResult.new(added: added_count, removed: removed_count)
        end
      end
    end
  end
end
