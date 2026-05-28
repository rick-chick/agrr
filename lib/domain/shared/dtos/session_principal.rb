# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # セッション Cookie または API キーから解決した「ログイン主体」。
      # ActiveRecord の User はアダプタ境界に閉じ、ドメイン・コントローラ・ビューは本 DTO のみを扱う。
      class SessionPrincipal
        attr_reader :id, :email, :name, :admin

        def initialize(id:, email:, name:, admin:, anonymous:)
          @id = id
          @email = email
          @name = name
          @admin = admin
          @anonymous = anonymous
        end

        def admin?
          @admin
        end

        def anonymous?
          @anonymous
        end

        def authenticated?
          !anonymous?
        end
      end
    end
  end
end
