# frozen_string_literal: true

# APIコントローラー用のCRUDレスポンスConcern
#
# @example 基本的な使用例
#   class Api::V1::Masters::CropsController < Api::V1::BaseController
#     include ApiCrudResponder
#     
#     def create
#       @crop = Crop.new(crop_params)
#       @crop.user = current_user
#       
#       respond_to_create(@crop)
#     end
#     
#     def update
#       respond_to_update(@crop)
#     end
#     
#     def destroy
#       respond_to_destroy(@crop)
#     end
#     
#     def show
#       respond_to_show(@crop)
#     end
#     
#     def index
#       @crops = Crop.all
#       respond_to_index(@crops)
#     end
#   end
#
# @example カスタムエラーレスポンスを指定する場合
#   def create
#     @crop = Crop.new(crop_params)
#     respond_to_create(@crop, error_serializer: ->(errors) { { messages: errors } })
#   end
module ApiCrudResponder
  extend ActiveSupport::Concern

  private

  # createアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 作成対象のリソース
  # @param status [Symbol] 成功時のHTTPステータス（デフォルト: :created）
  # @param error_serializer [Proc, nil] エラーをシリアライズするProc（デフォルト: { errors: full_messages }）
  def respond_to_create(resource, status: :created, error_serializer: nil)
    if resource.persisted?
      render json: resource, status: status
    else
      errors = error_serializer ? error_serializer.call(resource.errors) : { errors: resource.errors.full_messages }
      render json: errors, status: :unprocessable_entity
    end
  end

  # updateアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 更新対象のリソース
  # @param status [Symbol] 成功時のHTTPステータス（デフォルト: :ok）
  # @param error_serializer [Proc, nil] エラーをシリアライズするProc（デフォルト: { errors: full_messages }）
  # @param update_result [Boolean, nil] updateメソッドの戻り値（指定しない場合はresource.errors.empty?で判定）
  def respond_to_update(resource, status: :ok, error_serializer: nil, update_result: nil)
    success = update_result.nil? ? resource.errors.empty? : update_result
    if success
      render json: resource, status: status
    else
      errors = error_serializer ? error_serializer.call(resource.errors) : { errors: resource.errors.full_messages }
      render json: errors, status: :unprocessable_entity
    end
  end

  # destroyアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 削除対象のリソース
  # @param status [Symbol] 成功時のHTTPステータス（デフォルト: :no_content）
  # @param error_serializer [Proc, nil] エラーをシリアライズするProc（デフォルト: { errors: full_messages }）
  # @param destroy_result [Boolean, nil] destroyメソッドの戻り値（指定しない場合はresource.destroyed?で判定）
  def respond_to_destroy(resource, status: :no_content, error_serializer: nil, destroy_result: nil)
    success = destroy_result.nil? ? resource.destroyed? : destroy_result
    if success
      head status
    else
      errors = error_serializer ? error_serializer.call(resource.errors) : { errors: resource.errors.full_messages }
      render json: errors, status: :unprocessable_entity
    end
  end

  # showアクション用のレスポンス処理
  #
  # @param resource [ActiveRecord::Base] 表示対象のリソース
  # @param status [Symbol] HTTPステータス（デフォルト: :ok）
  def respond_to_show(resource, status: :ok)
    render json: resource, status: status
  end

  # indexアクション用のレスポンス処理
  #
  # @param resources [ActiveRecord::Relation, Array] 一覧表示対象のリソース
  # @param status [Symbol] HTTPステータス（デフォルト: :ok）
  def respond_to_index(resources, status: :ok)
    render json: resources, status: status
  end
end
