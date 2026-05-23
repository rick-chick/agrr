# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmNewMasterFormInteractor
        def initialize(output_port:, user_id:, gateway:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
        end

        def call
          snapshot = @gateway.blank_farm_master_form_snapshot_for_new!(user_id: @user_id)
          @output_port.on_success(snapshot)
        end
      end
    end
  end
end
