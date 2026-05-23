# frozen_string_literal: true

module Domain
  module Pesticide
    module Ports
      class PesticideHtmlPickListsOutputPort
        # @param pick_list_bundle [Domain::Pesticide::Dtos::PesticideHtmlPickListBundle]
        def on_success(pick_list_bundle)
          raise NotImplementedError, "Subclasses must implement on_success"
        end
      end
    end
  end
end
