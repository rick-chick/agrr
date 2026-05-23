# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # add_crop: 候補日付・圃場の探索（optimization_host 経由の I/O のみ）。
      class CultivationPlanAddCropBestCandidateGateway
        def initialize(logger:)
          @logger = logger
        end

        # @return [Hash] :found（field_id, start_date） / :no_candidates / :prediction_incomplete / :not_found / :unexpected
        def find_best(auth:, plan_id:, crop_id:, field_id:, display_range:, optimization_host:)
          raise NotImplementedError
        end

        protected

        attr_reader :logger
      end
    end
  end
end
