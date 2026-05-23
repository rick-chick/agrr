# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideHtmlPickListsInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          bundle = @gateway.pesticide_html_pick_list_bundle(
            crop_list_filter: Domain::Shared::Policies::CropPolicy.index_list_filter(user),
            pest_list_filter: Domain::Shared::Policies::PestPolicy.index_list_filter(user)
          )
          @output_port.on_success(bundle)
        end
      end
    end
  end
end
