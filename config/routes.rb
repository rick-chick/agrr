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

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors and load balancers.
  # Optimized: Only checks primary database for faster startup
  # NOTE: This route is defined outside the locale scope so that Cloud Run and load balancers
  # can reliably access `/up` without a locale prefix.
  get "/up" => "health#show", as: :rails_health_check

  # Locale switching with default locale optimization
  scope "(:locale)", locale: /ja|us|in/, defaults: { locale: 'ja' } do
    namespace :admin do
      # 管理画面のルート
      root to: redirect('/crops')
    end
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Authentication routes
    get '/auth/login', to: 'auth#login', as: 'auth_login'
    # Google OAuth routes (OmniAuth middleware handles /auth/google_oauth2)
    get '/auth/google_oauth2/callback', to: 'auth#google_oauth2_callback'
    get '/auth/failure', to: 'auth#failure'
    delete '/auth/logout', to: 'auth#logout', as: 'auth_logout'

    # API Key management routes
    get '/api_keys', to: 'api_keys#show', as: 'api_keys'
    post '/api_keys/generate', to: 'api_keys#generate', as: 'generate_api_key'
    post '/api_keys/regenerate', to: 'api_keys#regenerate', as: 'regenerate_api_key'

    # API Documentation
    get '/api/docs', to: 'api_docs#index', as: 'api_docs'

    # Farms and Fields routes (nested)
    resources :farms do
      resources :fields
      # Weather data endpoint for charts
      get 'weather_data', to: 'farms/weather_data#index'
    end

    # Crops (HTML) routes
    resources :crops do
      member do
        post :generate_task_schedule_blueprints
        post :toggle_task_template
      end
      resources :pests, controller: 'crops/pests', except: [:destroy]
      resources :agricultural_tasks, controller: 'crops/agricultural_tasks'
      resources :task_schedule_blueprints, only: [:destroy], controller: 'crops/task_schedule_blueprints' do
        member do
          patch :update_position
        end
      end
    end

    # Fertilizes (HTML) routes
    resources :fertilizes

    # Pests (HTML) routes
    resources :pests

    # Pesticides (HTML) routes
    resources :pesticides

    # Interaction Rules (連作ルール) routes
    resources :interaction_rules

  post 'undo_deletion', to: 'deletion_undos#create', as: :undo_deletion

    # Agricultural Tasks (農業タスク) routes
    resources :agricultural_tasks

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
      resource :task_schedule, only: [:show], module: :plans do
        resources :items,
                  controller: 'task_schedule_items',
                  only: [:create, :update, :destroy] do
          member do
            post :complete
          end
        end
      end
    end

    # Planning Schedules (数年に渡る作付け計画画面)
    resources :planning_schedules, only: [] do
      collection do
        get :fields_selection
        get :schedule
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
        # AI作物情報取得・保存エンドポイント
        post 'crops/ai_create', to: 'crops#ai_create'
        # AI肥料情報取得・保存エンドポイント
        post 'fertilizes/ai_create', to: 'fertilizes#ai_create'
        post 'fertilizes/:id/ai_update', to: 'fertilizes#ai_update'
        # AI害虫情報取得・保存エンドポイント
        post 'pests/ai_create', to: 'pests#ai_create'
        post 'pests/:id/ai_update', to: 'pests#ai_update'
        
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
        
        # GCP Cloud Scheduler用APIエンドポイント
        namespace :internal do
          resources :jobs, only: [] do
            collection do
              post 'trigger_weather_update'
            end
          end
        end
        
        # Backdoor API (ランダムトークン認証)
        namespace :backdoor do
          get 'status', to: 'backdoor#status'
          get 'health', to: 'backdoor#health'
          get 'users', to: 'backdoor#users'
          post 'users', to: 'backdoor#create_user'
          patch 'users/:id', to: 'backdoor#update_user'
          put 'users/:id', to: 'backdoor#update_user'
          get 'db/stats', to: 'backdoor#db_stats'
          post 'db/clear', to: 'backdoor#clear_db'
        end
        
        # Master Data Management API (API Key認証)
        namespace :masters do
          resources :crops, only: [:index, :show, :create, :update, :destroy] do
            resources :pests, only: [:index, :create, :destroy], controller: 'crops/pests'
            resources :agricultural_tasks, only: [:index, :create, :update, :destroy], controller: 'crops/agricultural_tasks'
            resources :crop_stages, only: [:index, :show, :create, :update, :destroy], controller: 'crops/crop_stages' do
              resource :temperature_requirement, only: [:show, :create, :update, :destroy], controller: 'crops/crop_stages/temperature_requirements'
              resource :sunshine_requirement, only: [:show, :create, :update, :destroy], controller: 'crops/crop_stages/sunshine_requirements'
              resource :thermal_requirement, only: [:show, :create, :update, :destroy], controller: 'crops/crop_stages/thermal_requirements'
              resource :nutrient_requirement, only: [:show, :create, :update, :destroy], controller: 'crops/crop_stages/nutrient_requirements'
            end
            resources :pesticides, only: [:index], controller: 'crops/pesticides'
          end
          resources :fertilizes, only: [:index, :show, :create, :update, :destroy]
          resources :pests, only: [:index, :show, :create, :update, :destroy]
          resources :pesticides, only: [:index, :show, :create, :update, :destroy]
          resources :farms, only: [:index, :show, :create, :update, :destroy] do
            resources :fields, only: [:index, :show, :create, :update, :destroy], controller: 'fields'
          end
          resources :fields, only: [:show, :update, :destroy] # 直接アクセス用（farm_id不要）
          resources :agricultural_tasks, only: [:index, :show, :create, :update, :destroy]
          resources :interaction_rules, only: [:index, :show, :create, :update, :destroy]
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
