# frozen_string_literal: true

# PlansControllerとPublicPlansControllerの共通機能を提供するConcern
#
# 使い方:
# - plan_typeを定義: 'private' または 'public'
# - session_keyを定義: セッションで使用するキー（例: :plan_data, :public_plan）
# - redirect_pathを定義: エラー時のリダイレクト先パス
# - find_cultivation_plan_scopeを実装: 計画を検索するスコープ
module CultivationPlanManageable
  extend ActiveSupport::Concern
  
  included do
    # サブクラスで定義すべきメソッドの例外
    class_attribute :plan_type, :session_key, :redirect_path_method
  end
  
  # 栽培計画を検索
  # サブクラスでfind_cultivation_plan_scopeを実装する必要がある
  def find_cultivation_plan
    plan_id = params[:id] || session_data[:plan_id]
    
    unless plan_id
      redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
      return nil
    end
    
    find_cultivation_plan_scope
      .includes(field_cultivations: [:cultivation_plan_field, :cultivation_plan_crop])
      .find(plan_id)
  rescue ActiveRecord::RecordNotFound
    redirect_to send(redirect_path_method), alert: I18n.t("#{i18n_scope}.errors.not_found")
    nil
  end
  
  # セッションデータを取得
  def session_data
    (session[session_key] || {}).with_indifferent_access
  end
  
  # 選択された作物IDを取得
  def crop_ids
    Rails.logger.debug "🔍 [CultivationPlanManageable] params[:crop_ids]: #{params[:crop_ids].inspect}"
    Rails.logger.debug "🔍 [CultivationPlanManageable] params keys: #{params.keys.inspect}"
    result = params[:crop_ids].presence || []
    Rails.logger.debug "🔍 [CultivationPlanManageable] crop_ids result: #{result.inspect}"
    result
  end
  
  # I18nスコープ（plans または public_plans）
  def i18n_scope
    plan_type == 'private' ? 'plans' : 'public_plans'
  end
  
  # 最適化進捗画面の共通処理
  def handle_optimizing(force_weather_only:)
    Rails.logger.info "🔍 [CultivationPlanManageable#handle_optimizing] Finding cultivation plan"
    @cultivation_plan = find_cultivation_plan
    return unless @cultivation_plan
    
    Rails.logger.info "📊 [CultivationPlanManageable#handle_optimizing] Plan status: #{@cultivation_plan.status}"
    if @cultivation_plan.status_completed?
      Rails.logger.info "✅ [CultivationPlanManageable#handle_optimizing] Plan completed, redirecting to completion page"
      redirect_to_completion_page
    end
    # 最適化ジョブは計画作成時に既に実行されているため、ここでは何もしない
  end
  
  private
  
  def redirect_to_completion_page
    completion_path = completion_redirect_path
    redirect_to send(completion_path, @cultivation_plan)
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

