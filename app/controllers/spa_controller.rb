# frozen_string_literal: true

class SpaController < ApplicationController
  skip_before_action :authenticate_user!

  def index
    index_path = Rails.root.join('public', 'index.html')
    unless File.exist?(index_path)
      render plain: "SPA build not found at #{index_path}", status: :internal_server_error
      return
    end

    render file: index_path, layout: false
  end
end
