# frozen_string_literal: true

Rails.application.routes.draw do
  # Development and test routes (outside locale scope for direct access)
  if Rails.env.development? || Rails.env.test?
    get '/auth/test/mock_login', to: 'auth_test#mock_login', as: 'auth_test_mock_login'
    get '/auth/test/mock_login_as/:user', to: 'auth_test#mock_login_as', as: 'auth_test_mock_login_as'
    get '/auth/test/mock_logout', to: 'auth_test#mock_logout', as: 'auth_test_mock_logout'
    
    # Client-side JavaScript logging
    namespace :dev do
      post '/client_logs', to: 'client_logs#create'
    end
    
    # UI System Demo
    namespace :demo do
      get 'ui_system', to: 'demo#ui_system'
    end
  end

  # Locale switching with default locale optimization
  scope "(:locale)", locale: /ja|us|in/, defaults: { locale: 'ja' } do
    namespace :admin do
      # 管理画面のルート
      root to: redirect('/crops')
    end
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by uptime monitors and load balancers.
    get "up" => "rails/health#show", as: :rails_health_check

    # Authentication routes
    get '/auth/login', to: 'auth#login', as: 'auth_login'
    # Google OAuth routes (OmniAuth middleware handles /auth/google_oauth2)
    get '/auth/google_oauth2/callback', to: 'auth#google_oauth2_callback'
    get '/auth/failure', to: 'auth#failure'
    delete '/auth/logout', to: 'auth#logout', as: 'auth_logout'

    # Farms and Fields routes (nested)
    resources :farms do
      resources :fields
      # Weather data endpoint for charts
      get 'weather_data', to: 'farms/weather_data#index'
    end

    # Crops (HTML) routes
    resources :crops

    # Fertilizes (HTML) routes
    resources :fertilizes

    # Pests (HTML) routes
    resources :pests

    # Pesticides (HTML) routes
    resources :pesticides

    # Interaction Rules (連作ルール) routes
    resources :interaction_rules

    # Public Plans (公開作付け計画 - 認証不要) routes
    resources :public_plans, only: [:create] do
      collection do
        get :new, path: ''  # GET /public_plans → public_plans#new (public_plans_path)
        get :select_farm_size
        get :select_crop
        get :optimizing
        get :results
        post :save_plan
        get :process_saved_plan
      end
    end

    # Free Plans (旧システム - リダイレクト用)
    get '/free_plans', to: redirect('/public_plans/new')
    get '/free_plans/*path', to: redirect('/public_plans/new')
    
    # Plans (個人用作付け計画 - 認証必須)
    resources :plans do
      collection do
        get :select_crop
      end
      member do
        get :optimizing
        post :copy
        post :optimize
      end
    end

    # ActionCable for WebSocket
    mount ActionCable.server => '/cable'
    
    # API routes
    namespace :api do
      namespace :v1 do
        # Health check endpoint
        get 'health', to: 'base#health_check'
        # File management endpoints
        resources :files, only: [:index, :show, :create, :destroy]
        # Farm and Field management endpoints
        resources :farms, controller: 'farms/farm_api', only: [:index, :show, :create, :update, :destroy] do
          resources :fields, controller: 'fields/field_api', only: [:index, :show, :create, :update, :destroy]
        end
        resources :crops, controller: 'crops/crop_api', only: [:index, :show, :create, :update, :destroy]
        # AI作物情報取得・保存エンドポイント
        post 'crops/ai_create', to: 'crops#ai_create'
        resources :fertilizes, controller: 'fertilizes/fertilize_api', only: [:index, :show, :create, :update, :destroy] do
          # AI肥料情報取得・保存エンドポイント
          collection do
            post 'ai_create', to: 'fertilizes#ai_create'
          end
          member do
            post 'ai_update', to: 'fertilizes#ai_update'
          end
        end
        
        # Public Plans API（認証不要）
        namespace :public_plans do
          resources :field_cultivations, only: [:show, :update] do
            member do
              get :climate_data
            end
          end
          resources :cultivation_plans, only: [] do
            member do
              post :adjust
              post :add_crop
              post :add_field
              delete 'remove_field/:field_id', action: :remove_field, as: :remove_field
              get :data
            end
          end
        end
        
        # Plans API（認証必須）
        namespace :plans do
          resources :field_cultivations, only: [:show, :update] do
            member do
              get :climate_data
            end
          end
          resources :cultivation_plans, only: [] do
            member do
              post :adjust
              post :add_crop
              post :add_field
              delete 'remove_field/:field_id', action: :remove_field, as: :remove_field
              get :data
            end
          end
        end
        
        # Weather API endpoints
        namespace :weather do
          get 'historical', to: 'weather#historical'
          get 'forecast', to: 'weather#forecast'
          get 'status', to: 'weather#status'
        end
        
        # 内部スクリプト専用APIエンドポイント（開発・テスト環境のみ）
        post 'internal/farms/:farm_id/fetch_weather_data', to: 'internal#fetch_weather_data'
        get 'internal/farms/:farm_id/weather_status', to: 'internal#weather_status'
        get 'internal/farms/:farm_id/weather_data', to: 'internal#get_weather_data'
        
        # Backdoor API (ランダムトークン認証)
        namespace :backdoor do
          get 'status', to: 'backdoor#status'
          get 'health', to: 'backdoor#health'
        end
      end
    end

    # Static pages
    get '/privacy', to: 'pages#privacy', as: 'privacy'
    get '/terms', to: 'pages#terms', as: 'terms'
    get '/contact', to: 'pages#contact', as: 'contact'
    get '/about', to: 'pages#about', as: 'about'
    
    # Sitemap
    get '/sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }

    # Home page
    root "home#index"
  end # locale scope
end
