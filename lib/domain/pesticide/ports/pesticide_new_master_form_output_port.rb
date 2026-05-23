# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideNewMasterFormOutputPort
        # @param bundle [Domain::Pesticide::Dtos::PesticideMasterFormBundle]
        def on_success(bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
