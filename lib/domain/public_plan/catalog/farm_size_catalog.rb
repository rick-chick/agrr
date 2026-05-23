# frozen_string_literal: true

module Domain
  module PublicPlan
    module Catalog
      # 公開プランウィザードの農場サイズ定義（単一の正）。
      module FarmSizeCatalog
        ENTRIES = [
          { id: "home_garden", area_sqm: 30 },
          { id: "community_garden", area_sqm: 50 },
          { id: "rental_farm", area_sqm: 300 }
        ].freeze

        ALLOWED_IDS = ENTRIES.map { |e| e[:id] }.freeze

        def self.find_by_id(farm_size_id)
          return nil if farm_size_id.blank?

          ENTRIES.find do |size|
            size[:id].to_s == farm_size_id.to_s || size[:area_sqm] == farm_size_id.to_i
          end
        end

        def self.all
          ENTRIES
        end
      end
    end
  end
end
