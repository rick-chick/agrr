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

        def call(crop_id:)
          user = @user_lookup.find(@user_id)
          accessible_pest_ids = @pest_gateway.selectable_pest_ids(user)
          pests = @pest_gateway.list_pests_for_crop_filtered(
            crop_id: crop_id,
            pest_ids: accessible_pest_ids,
            order: :id_asc # API: 安定した一覧順（従来の不定順に依存しない）
          )
          @output_port.on_success(pests)
        end
      end
    end
  end
end
