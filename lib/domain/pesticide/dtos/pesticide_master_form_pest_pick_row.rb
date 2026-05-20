# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタ HTML の害虫プルダウン用（id / name のみ）。
      class PesticideMasterFormPestPickRow
        attr_reader :id, :name

        def initialize(id:, name:)
          @id = id
          @name = name
        end
      end
    end
  end
end
