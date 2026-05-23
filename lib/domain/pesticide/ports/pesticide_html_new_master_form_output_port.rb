# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideHtmlNewMasterFormOutputPort
        # @param bundle [Domain::Pesticide::Dtos::PesticideHtmlMasterFormBundle]
        def on_success(bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
