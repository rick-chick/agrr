# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideHtmlNewMasterFormInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          bundle = @gateway.pesticide_html_master_form_bundle(user: user, assign_attributes: {})
          @output_port.on_success(bundle)
        end
      end
    end
  end
end
