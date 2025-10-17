# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:privacy, :terms, :contact, :about]

  def privacy
    # プライバシーポリシーページ
  end

  def terms
    # 利用規約ページ
  end

  def contact
    # お問い合わせページ
  end

  def about
    # サイト概要ページ
  end
end

