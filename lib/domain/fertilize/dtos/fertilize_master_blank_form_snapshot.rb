# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料マスタ「新規」フォーム用の初期属性（永続化しない）。
      class FertilizeMasterBlankFormSnapshot
        attr_reader :attributes

        def initialize(attributes)
          @attributes = attributes.transform_keys(&:to_sym).freeze
        end
      end
    end
  end
end
