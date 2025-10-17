# frozen_string_literal: true

class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @base_url = request.base_url
    
    respond_to do |format|
      format.xml
    end
  end
end

