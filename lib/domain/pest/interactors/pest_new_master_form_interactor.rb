# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestHtmlNewMasterFormInteractor
        def initialize(output_port:, user_id:, gateway:, user_lookup:, raw_crop_ids:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @user_lookup = user_lookup
          @raw_crop_ids = raw_crop_ids
        end

        def call
          user = @user_lookup.find(@user_id)
          state = @gateway.pest_html_new_form_state!(user: user, raw_crop_ids: @raw_crop_ids)
          @output_port.on_success(state)
        end
      end
    end
  end
end
