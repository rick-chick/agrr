# frozen_string_literal: true

# PlansController と PublicPlansController の共通機能（レガシー HTML フロー）
#
# 使い方:
# - session_key: セッションで使用するキー（例: :public_plan）
class CultivationPlanHtmlBaseController < ApplicationController
  class_attribute :session_key

  # セッションデータを取得
  def session_data
    (session[session_key] || {}).with_indifferent_access
  end

  # 選択された作物IDを取得
  def crop_ids
    params[:crop_ids].presence || []
  end
end
