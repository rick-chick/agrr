# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class CropsNestedPestsNewInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        def call(crop_id:)
          user = @user_lookup.find(@user_id)
          blank_snapshot = Domain::Pest::Dtos::PestCropNestSnapshot.blank_for_nested_new(user_id: user.id)
          available_entities = @pest_gateway.list_selectable_pest_entities_recent_first(user)
          linked_pest_ids = @pest_gateway.pest_ids_linked_to_crop(crop_id: crop_id)
          unassociated_pests = available_entities.reject { |e| linked_pest_ids.include?(e.id) }
          @output_port.on_success(pest_crop_nest_snapshot: blank_snapshot, unassociated_pests:)
        end
      end
    end
  end
end
