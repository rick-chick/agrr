# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    if logged_in?
      # Redirect to dashboard or show welcome page
      @user = current_user
    else
      # Redirect to login if not authenticated
      redirect_to auth_login_path
    end
  end
end