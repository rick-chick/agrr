# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # SaveAdjustedAgrr*Input の `from_hash` で Agrr/JSON 混在キーを読む共通処理。
      module SaveAdjustedAgrrHashPick
        module_function

        # @param h [Hash, Object]
        # @param key [Symbol]
        def pick(h, key)
          return nil unless h.is_a?(Hash)

          v = h[key.to_s]
          return v unless v.nil?

          h[key.to_sym]
        end
      end
    end
  end
end
