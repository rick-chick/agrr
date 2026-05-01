# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class MastersCropPesticidesIndexInteractor
        def initialize(output_port:, user_id:, user_lookup:, pesticide_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pesticide_gateway = pesticide_gateway
        end

        def call(crop)
          user = @user_lookup.find(@user_id)
          crop_id = crop.respond_to?(:id) ? crop.id : crop
          pesticides = @pesticide_gateway.list_for_crop_with_user(crop_id: crop_id, user: user)
          @output_port.on_success(pesticides)
        end
      end
    end
  end
end
