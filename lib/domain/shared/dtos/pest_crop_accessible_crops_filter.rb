# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # 害虫に紐づけ可能な作物集合の条件（永続層に依存しない）。
      # ActiveRecord::Relation の組み立てはアダプター／ポリシーで行う。
      class PestCropAccessibleCropsFilter
        # @param reference_pest [Boolean] 参照データの害虫か
        # @param scoped_user_id [Integer, nil] 非参照害虫のとき作物の user_id 条件（参照害虫では未使用）
        # @param region [String, nil] 設定時のみ作物を地域で絞る
        def initialize(reference_pest:, scoped_user_id:, region:)
          @reference_pest = reference_pest
          @scoped_user_id = scoped_user_id
          @region = region
        end

        def reference_pest?
          @reference_pest
        end

        attr_reader :scoped_user_id, :region
      end
    end
  end
end
