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

        def call(crop)
          user = @user_lookup.find(@user_id)
          pest = @pest_gateway.build_blank_pest_for_form

          available_entities = @pest_gateway.list_selectable_pest_entities_recent_first(user)
          existing_pest_ids = crop.respond_to?(:pest_ids) ? crop.pest_ids : []
          unassociated_pests = available_entities.reject { |e| existing_pest_ids.include?(e.id) }
          @output_port.on_success(pest:, unassociated_pests:)
        end
      end
    end
  end
end
