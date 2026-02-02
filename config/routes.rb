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

    # API Documentation
    get '/api/docs', to: 'api_docs#index', as: 'api_docs'

    post 'undo_deletion', to: 'deletion_undos#create', as: :undo_deletion

    # HTML マスタ（Rails コントローラ・ナビで _path を参照するため）
    resources :farms do
      resources :fields, controller: 'fields'
      get 'weather_data', to: 'farms/weather_data#index', as: 'weather_data'
    end
    resources :crops do
      member do
        post :generate_task_schedule_blueprints
        post :toggle_task_template
      end
      resources :crop_stages, only: [:index, :show, :create, :update, :destroy], controller: 'crops/crop_stages'
      resources :pests, controller: 'crops/pests'
      resources :agricultural_tasks, controller: 'crops/agricultural_tasks'
      resources :task_schedule_blueprints, only: [:destroy], controller: 'crops/task_schedule_blueprints' do
        member do
          patch :update_position
        end
      end
    end
    resources :fertilizes
    resources :pesticides
    resources :pests
    resources :agricultural_tasks
    resources :interaction_rules

    # APIキー管理（HTML）
    get 'api_keys', to: 'api_keys#show', as: 'api_keys'
    post 'api_keys/generate', to: 'api_keys#generate', as: 'generate_api_key'
    post 'api_keys/regenerate', to: 'api_keys#regenerate', as: 'regenerate_api_key'

    # HTML Plans（ナビ等で plans_path / public_plans_path を参照するため）
    resources :plans, only: [:index, :show, :new, :create, :destroy] do
      collection do
        get :select_crop
      end
      member do
        post :optimize
        get :optimizing
        post :copy
      end
      resource :task_schedule, only: [:show], controller: 'plans/task_schedules'
      resources :task_schedule_items, only: [:create, :update, :destroy], controller: 'plans/task_schedule_items' do
        member do
          post :complete
        end
      end
    end
    get 'public_plans', to: 'public_plans#new', as: 'public_plans'
    post 'public_plans', to: 'public_plans#create'
    get 'public_plans/select_farm_size', to: 'public_plans#select_farm_size', as: 'select_farm_size_public_plans'
    get 'public_plans/select_crop', to: 'public_plans#select_crop', as: 'select_crop_public_plans'
    post 'public_plans/save_plan', to: 'public_plans#save_plan', as: 'save_plan_public_plans'
    get 'public_plans/process_saved_plan', to: 'public_plans#process_saved_plan', as: 'process_saved_plan_public_plans'
    get 'public_plans/optimizing', to: 'public_plans#optimizing', as: 'optimizing_public_plans'
    get 'public_plans/results', to: 'public_plans#results', as: 'public_plans_results'

    # HTML Planning Schedules（ナビで fields_selection_planning_schedules_path を参照するため）
    get 'planning_schedules/fields_selection', to: 'planning_schedules#fields_selection', as: 'fields_selection_planning_schedules'
    get 'planning_schedules/schedule', to: 'planning_schedules#schedule', as: 'schedule_planning_schedules'

    # ActionCable for WebSocket
    mount ActionCable.server => '/cable'
    
    # API routes
    namespace :api do
      namespace :v1 do
        # Health check endpoint
        get 'health', to: 'base#health_check'
        # Auth endpoints
        get 'auth/me', to: 'auth#me'
        delete 'auth/logout', to: 'auth#logout'
        # API Key endpoints
        post 'api_keys/generate', to: 'api_keys#generate'
        post 'api_keys/regenerate', to: 'api_keys#regenerate'
        # Plans summary endpoints
        get 'plans', to: 'plans#index'
        get 'plans/:id', to: 'plans#show'
        post 'plans', to: 'plans#create'
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
          get :farms, to: 'wizard#farms'
          get :farm_sizes, to: 'wizard#farm_sizes'
          get :crops, to: 'wizard#crops'
          post :plans, to: 'wizard#create'
          post :save_plan
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

    # Static pages（ナビ・cookie consent で privacy_path 等を参照）
    get 'privacy', to: 'pages#privacy', as: 'privacy'
    get 'terms', to: 'pages#terms', as: 'terms'
    get 'contact', to: 'pages#contact', as: 'contact'
    get 'about', to: 'pages#about', as: 'about'

    # Static pages (Angular SPA side handles these routes)
    
    # Sitemap
    get '/sitemap.xml', to: 'sitemaps#index', defaults: { format: 'xml' }

    # Home page (SPA entry)
    root "spa#index"

    # SPA fallback (exclude API/auth/rails/cable)
    get '*path', to: 'spa#index', constraints: lambda { |req|
      req.format.html? &&
        !req.path.start_with?('/api') &&
        !req.path.start_with?('/auth') &&
        !req.path.start_with?('/rails') &&
        !req.path.start_with?('/cable')
    }
  end # locale scope
end
