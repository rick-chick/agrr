# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanCreateInput
        attr_reader :farm_id, :farm_size_id, :crop_ids, :session_id, :user, :redirect_path

        def initialize(farm_id:, farm_size_id:, crop_ids:, session_id:, user: nil, redirect_path: nil)
          @farm_id = farm_id
          @farm_size_id = farm_size_id
          @crop_ids = crop_ids
          @session_id = session_id
          @user = user
          @redirect_path = redirect_path
        end
      end
    end
  end
end
