# frozen_string_literal: true

class ApiKeysController < ApplicationController
  before_action :authenticate_user!

  # GET /api_keys
  def show
    @user = current_user
  end

  # POST /api_keys/generate
  def generate
    @user = current_user
    
    if @user.generate_api_key!
      flash[:notice] = I18n.t('api_keys.flash.generate.success')
      redirect_to api_keys_path
    else
      flash[:alert] = I18n.t('api_keys.flash.generate.failure')
      redirect_to api_keys_path
    end
  end

  # POST /api_keys/regenerate
  def regenerate
    @user = current_user
    
    if @user.regenerate_api_key!
      flash[:notice] = I18n.t('api_keys.flash.regenerate.success')
      redirect_to api_keys_path
    else
      flash[:alert] = I18n.t('api_keys.flash.regenerate.failure')
      redirect_to api_keys_path
    end
  end
end
