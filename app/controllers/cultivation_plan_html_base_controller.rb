# frozen_string_literal: true

# PlansController と PublicPlansController の共通機能（HTML フロー）
#
# 使い方:
# - plan_type: 'private' または 'public'
# - session_key: セッションで使用するキー（例: :plan_data, :public_plan）
# - redirect_path_method: エラー時のリダイレクト先ヘルパー名（シンボル）
# - select_crop_redirect_path, optimizing_redirect_path, completion_redirect_path を実装
class CultivationPlanHtmlBaseController < ApplicationController
  class_attribute :plan_type, :session_key, :redirect_path_method

  # セッションデータを取得
  def session_data
    (session[session_key] || {}).with_indifferent_access
  end

  # 選択された作物IDを取得
  def crop_ids
    params[:crop_ids].presence || []
  end

  # I18nスコープ（plans または public_plans）
  def i18n_scope
    plan_type == "private" ? "plans" : "public_plans"
  end

  private

  # サブクラスで実装すべきメソッド

  # 作物選択画面へのリダイレクトパス
  def select_crop_redirect_path
    raise NotImplementedError, "#{self.class}#select_crop_redirect_path must be implemented"
  end

  # 最適化中画面へのリダイレクトパス
  def optimizing_redirect_path
    raise NotImplementedError, "#{self.class}#optimizing_redirect_path must be implemented"
  end

  # 完了時のリダイレクトパス
  def completion_redirect_path
    raise NotImplementedError, "#{self.class}#completion_redirect_path must be implemented"
  end
end
