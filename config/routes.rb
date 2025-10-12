# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :admin do
    resources :farm_sizes
    resources :default_farms, only: [:index, :show, :edit, :update, :destroy]
    
    # 管理画面のルート
    root to: redirect('/admin/default_farms')
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors and load balancers.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication routes
  get '/auth/login', to: 'auth#login', as: 'auth_login'
  get '/auth/google_oauth2', to: 'auth#google_oauth2'
  get '/auth/google_oauth2/callback', to: 'auth#google_oauth2_callback'
  get '/auth/failure', to: 'auth#failure'
  delete '/auth/logout', to: 'auth#logout', as: 'auth_logout'
  
  # Development and test routes
  if Rails.env.development? || Rails.env.test?
    get '/auth/test/mock_login', to: 'auth_test#mock_login', as: 'auth_test_mock_login'
    get '/auth/test/mock_login_as/:user', to: 'auth_test#mock_login_as', as: 'auth_test_mock_login_as'
    get '/auth/test/mock_logout', to: 'auth_test#mock_logout', as: 'auth_test_mock_logout'
  end

  # Farms and Fields routes (nested)
  resources :farms do
    resources :fields
    # Weather data endpoint for charts
    get 'weather_data', to: 'farms/weather_data#index'
  end

  # Crops (HTML) routes
  resources :crops

  # Free Plans (無料ユーザー向け作付け計画) routes
  resources :free_plans, only: [:new, :create, :show] do
    member do
      get :calculating
    end
    collection do
      get :select_farm_size
      get :select_crop
      get :calculating_all, path: 'calculating'
      get :results
    end
  end

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
    end
  end

  # Root route - 簡単作付け計画をトップページに設定
  root "free_plans#new"
end
