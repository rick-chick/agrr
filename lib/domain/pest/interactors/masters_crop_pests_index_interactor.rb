# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class MastersCropPestsIndexInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        # @param crop [Crop] ActiveRecord（set_crop で既に検証済み）
        def call(crop)
          user = @user_lookup.find(@user_id)
          accessible_pest_ids = @pest_gateway.selectable_pest_ids(user)
          pests = crop.pests.where(id: accessible_pest_ids)
          @output_port.on_success(pests)
        end
      end
    end
  end
end
