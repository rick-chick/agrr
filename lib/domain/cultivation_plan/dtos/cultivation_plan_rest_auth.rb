# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # REST 栽培計画 API（private / public）の認可モード。Gateway がスコープ付き find に使う。
      class CultivationPlanRestAuth
        attr_reader :mode, :user_id

        # @param mode [:private, :public]
        # @param user_id [Integer, nil] private のとき必須
        def initialize(mode:, user_id: nil)
          @mode = mode
          @user_id = user_id
        end

        def private?
          mode == :private
        end

        def public?
          mode == :public
        end

        def self.for_api_controller(controller)
          if controller.class.name.include?("::PublicPlans::")
            new(mode: :public, user_id: nil)
          else
            new(mode: :private, user_id: controller.send(:current_user).id)
          end
        end
      end
    end
  end
end
