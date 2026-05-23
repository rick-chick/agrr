# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 未保存害虫フォーム等、永続 {::Pest} をゲートウェイ境界に渡さず作物 ID 正規化に必要な属性だけを渡す。
      class PestCropFormAssociationContext
        attr_reader :is_reference, :pest_owner_user_id, :region

        # @param is_reference [Boolean]
        # @param pest_owner_user_id [Integer, nil] ユーザー害虫の所有者。nil のとき normalize 側で current user を使う。
        # @param region [String, nil]
        def initialize(is_reference: false, pest_owner_user_id: nil, region: nil)
          @is_reference = is_reference
          @pest_owner_user_id = pest_owner_user_id
          @region = region
        end
      end
    end
  end
end
