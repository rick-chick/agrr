# frozen_string_literal: true

class SitemapsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index]

  def index
    @base_url = request.base_url
    @research_pages = Dir.glob(Rails.root.join('public', 'research', '**', '*.html'))
                         .reject { |path| path.include?('/assets/') || path.end_with?('/404.html') || File.basename(path).start_with?('README') }
                         .map { |path| path.delete_prefix("#{Rails.root.join('public')}/") }
    
    respond_to do |format|
      format.xml
    end
  end
end

