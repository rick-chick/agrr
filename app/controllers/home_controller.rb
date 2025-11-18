# frozen_string_literal: true

class HomeController < ApplicationController
  # トップページは認証不要
  skip_before_action :authenticate_user!, only: [:index]
  layout 'public', only: [:index]

  def index
    # ランディングページ
  end
end
