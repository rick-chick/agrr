# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # 作業予定アイテム更新（Plans API）。Strong params に含まれるキーのみを保持し、未送信の属性は更新ハッシュに載せない。
      class TaskScheduleItemUpdateInput
        def initialize(params_hash)
          @params_hash = Domain::Shared.symbolize_keys(params_hash.to_h)
        end

        def self.from_params(raw)
          new(raw.to_h)
        end

        # Mutation Gateway / AR update 用（文字列キー）。リクエストに含まれたキーのみ。
        def to_update_attributes_seed
          @params_hash.transform_keys(&:to_s)
        end
      end
    end
  end
end
