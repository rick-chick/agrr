# frozen_string_literal: true

# PlansController と PublicPlansController の共通機能（HTML フロー）
#
# 使い方:
# - plan_type: 'private' または 'public'
# - session_key: セッションで使用するキー（例: :plan_data, :public_plan）
# - redirect_path_method: エラー時のリダイレクト先ヘルパー名（シンボル）
# - find_cultivation_plan_scope を実装: 計画を検索するスコープ
# - select_crop_redirect_path, optimizing_redirect_path, completion_redirect_path を実装
class CultivationPlanHtmlBaseController < ApplicationController
  class_attribute :plan_type, :session_key, :redirect_path_method

  # 栽培計画を検索
  # サブクラスで find_cultivation_plan_scope を実装する必要がある
  def find_cultivation_plan
    plan_id = params[:id] || session_data[:plan_id]

    unless plan_id
      redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
      return nil
    end

    scoped = find_cultivation_plan_scope
      .includes(field_cultivations: [ :cultivation_plan_field, :cultivation_plan_crop ])

    result = Adapters::CultivationPlan::ManageablePrivatePlanLookup.call(scope: scoped, plan_id: plan_id)

    if result[:kind] == :not_found
      redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
      return nil
    end

    result[:plan]
  end

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

  # 計画を検索するスコープ
  def find_cultivation_plan_scope
    raise NotImplementedError, "#{self.class}#find_cultivation_plan_scope must be implemented"
  end

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
