# frozen_string_literal: true

# app/gateways/agrr/progress_gateway を DI 可能にするための default レジストリ（Interactor のデフォルト引数用）
module Domain
  module AgriculturalTask
    module Gateways
      class AgrrProgressGateway
        class << self
          def default
            @default ||= ::Agrr::ProgressGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end
      end
    end
  end
end
