# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanCreateInputDto
        attr_reader :farm_id, :farm_size_id, :crop_ids, :session_id, :user

        def initialize(farm_id:, farm_size_id:, crop_ids:, session_id:, user: nil)
          @farm_id = farm_id
          @farm_size_id = farm_size_id
          @crop_ids = crop_ids
          @session_id = session_id
          @user = user
        end
      end
    end
  end
end
