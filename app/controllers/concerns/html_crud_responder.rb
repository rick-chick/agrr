# frozen_string_literal: true

# HTMLコントローラー用のCRUDレスポンスConcern
#
# @example 基本的な使用例
#   class FarmsController < ApplicationController
#     include HtmlCrudResponder
#     
#     def create
#       @farm = Farm.new(farm_params)
#       @farm.user = current_user
#       
#       respond_to_create(@farm, notice: I18n.t('farms.flash.created'))
#     end
#     
#     def update
#       respond_to_update(@farm, notice: I18n.t('farms.flash.updated'))
#     end
#   end
#
# @example カスタムリダイレクト先を指定する場合
#   def create
#     @field = @farm.fields.build(field_params)
#     respond_to_create(@field, 
#       notice: I18n.t('fields.flash.created'),
#       redirect_path: field_path(@farm, @field)
#     )
#   end
module HtmlCrudResponder
  extend ActiveSupport::Concern

  private

  # createアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 作成対象のリソース
  # @param notice [String, nil] 成功時の通知メッセージ
  # @param alert [String, nil] 成功時の警告メッセージ
  # @param redirect_path [String, nil] カスタムリダイレクト先（指定しない場合はresourceのshowページ）
  # @param render_action [Symbol] 失敗時にレンダーするアクション（デフォルト: :new）
  def respond_to_create(resource, notice: nil, alert: nil, redirect_path: nil, render_action: :new)
    if resource.persisted?
      path = redirect_path || resource
      redirect_to path, notice: notice, alert: alert
    else
      render render_action, status: :unprocessable_entity
    end
  end

  # updateアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 更新対象のリソース
  # @param notice [String, nil] 成功時の通知メッセージ
  # @param alert [String, nil] 成功時の警告メッセージ
  # @param redirect_path [String, nil] カスタムリダイレクト先（指定しない場合はresourceのshowページ）
  # @param render_action [Symbol] 失敗時にレンダーするアクション（デフォルト: :edit）
  # @param update_result [Boolean, nil] updateメソッドの戻り値（指定しない場合はresource.errors.empty?で判定）
  def respond_to_update(resource, notice: nil, alert: nil, redirect_path: nil, render_action: :edit, update_result: nil)
    success = update_result.nil? ? resource.errors.empty? : update_result
    if success
      path = redirect_path || resource
      redirect_to path, notice: notice, alert: alert
    else
      render render_action, status: :unprocessable_entity
    end
  end
end
