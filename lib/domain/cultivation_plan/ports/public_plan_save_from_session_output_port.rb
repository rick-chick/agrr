# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class PublicPlanSaveFromSessionOutputPort
        # @param success [Dtos::PublicPlanSaveSuccess, nil]
        def on_success(success = nil)
          raise NotImplementedError
        end

        # @param failure [Domain::CultivationPlan::Dtos::PublicPlanSaveFailure]
        def on_failure(failure)
          raise NotImplementedError
        end
      end
    end
  end
end
