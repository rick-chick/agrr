# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # HTML ウィザード Step3 — `PlansController#create` の入力（セッション + フォーム）。
      class PrivatePlanHtmlCreateInputDto
        attr_reader :farm_id, :crop_ids, :plan_name, :total_area, :user

        # @param farm_id [Integer, nil] セッションの farm_id をルート用パーサで正規化した値
        # @param total_area [Numeric, String, nil] セッションの total_area（未設定時は Gateway が圃場合計を算出）
        def initialize(farm_id:, crop_ids:, user:, plan_name: nil, total_area: nil)
          @farm_id = farm_id
          @crop_ids = Array(crop_ids).map(&:to_i).reject(&:zero?)
          @plan_name = plan_name
          @total_area = total_area
          @user = user
        end
      end
    end
  end
end
