# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタ HTML の作物プルダウン用（id / name のみ。Relation を契約に載せない）。
      class PesticideMasterFormCropPickRow
        attr_reader :id, :name

        def initialize(id:, name:)
          @id = id
          @name = name
        end
      end
    end
  end
end
