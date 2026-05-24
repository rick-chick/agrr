# frozen_string_literal: true

module Domain
  module Pest
    module Mappers
      # AI / UI から渡る affected_crops 配列から crop_id を抽出する（永続化・認可なし）。
      class PestAiAffectedCropsPayloadMapper
        def self.extract_crop_ids(affected_crops)
          Array(affected_crops).filter_map do |entry|
            if entry.is_a?(Hash)
              entry["crop_id"] || entry[:crop_id] || entry["crop_id".to_sym]
            elsif entry.respond_to?(:[])
              entry["crop_id"] || entry[:crop_id]
            elsif entry.respond_to?(:crop_id)
              entry.crop_id
            end
          end.compact.reject(&:blank?).map(&:to_i).uniq
        end

        def self.extract_crop_names(affected_crops)
          Array(affected_crops).filter_map do |entry|
            if entry.is_a?(Hash)
              entry["crop_name"] || entry[:crop_name] || entry["crop_name".to_sym]
            elsif entry.respond_to?(:[])
              entry["crop_name"] || entry[:crop_name]
            elsif entry.respond_to?(:crop_name)
              entry.crop_name
            end
          end.compact.reject(&:blank?).map(&:to_s).uniq
        end
      end
    end
  end
end
