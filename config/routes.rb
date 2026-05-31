# frozen_string_literal: true

Rails.application.routes.draw do
  if Rails.env.development? || Rails.env.test?
    get "/auth/test/mock_login", to: "auth_test#mock_login", as: "auth_test_mock_login"
    get "/auth/test/mock_login_as/:user", to: "auth_test#mock_login_as", as: "auth_test_mock_login_as"
    get "/auth/test/mock_logout", to: "auth_test#mock_logout", as: "auth_test_mock_logout"

    namespace :dev do
      post "/client_logs", to: "client_logs#create"
    end

    namespace :demo do
      get "ui_system", to: "demo#ui_system"
    end
  end

  get "/up" => "health#show", as: :rails_health_check

  scope "(:locale)", locale: /ja|us|in/, defaults: { locale: "ja" } do
    namespace :admin do
      root to: redirect(
        "#{ENV.fetch("FRONTEND_URL", "http://localhost:4200").split(",").map(&:strip).reject(&:empty?).first}/crops",
        allow_other_host: true
      )
    end

    get "/api/docs", to: "api_docs#index", as: "api_docs"

    get "privacy", to: "pages#privacy", as: "privacy"
    get "terms", to: "pages#terms", as: "terms"
    get "contact", to: "pages#contact", as: "contact"
    get "about", to: "pages#about", as: "about"

    get "/sitemap.xml", to: "sitemaps#index", defaults: { format: "xml" }

    root "spa#index"

    get "*path", to: "spa#index", constraints: lambda { |req|
      req.format.html? &&
        !req.path.start_with?("/api") &&
        !req.path.start_with?("/auth") &&
        !req.path.start_with?("/rails") &&
        !req.path.start_with?("/cable")
    }
  end
end
