# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :authenticate_user!

  # GET /api_keys
  def show
    @user = current_user
  end

  # POST /api_keys/generate
  def generate
    presenter = Presenters::Html::ApiKeys::UserApiKeyRotateHtmlPresenter.new(view: self, regenerate: false)
    Domain::ApiKeys::Interactors::ApiUserApiKeyRotateInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.user_api_key_rotation_gateway
    ).call(user_id: current_user.id, regenerate: false)
  end

  # POST /api_keys/regenerate
  def regenerate
    presenter = Presenters::Html::ApiKeys::UserApiKeyRotateHtmlPresenter.new(view: self, regenerate: true)
    Domain::ApiKeys::Interactors::ApiUserApiKeyRotateInteractor.new(
      output_port: presenter,
      gateway: CompositionRoot.user_api_key_rotation_gateway
    ).call(user_id: current_user.id, regenerate: true)
  end
end
