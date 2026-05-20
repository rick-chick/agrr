# frozen_string_literal: true

module Adapters
  module Shared
    module Dtos
      # `ApplicationController#current_user` 向けの非 AR DTO。
      # セッション Cookie から取得したユーザー情報をドメイン・ビュー両層に渡す。
      class SessionUserDto
        attr_reader :id, :name, :email, :avatar_url, :api_key

        def initialize(id:, name:, email:, avatar_url:, api_key:, admin:, anonymous:)
          @id = id
          @name = name
          @email = email
          @avatar_url = avatar_url
          @api_key = api_key
          @admin = admin
          @anonymous = anonymous
        end

        def admin?
          @admin
        end

        def admin
          @admin
        end

        def anonymous?
          @anonymous
        end

        def has_api_key?
          api_key.present?
        end
      end
    end
  end
end
