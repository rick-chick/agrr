# frozen_string_literal: true

Rails.application.routes.draw do
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
  
  # Development test routes
  if Rails.env.development?
    get '/auth/test/mock_login', to: 'auth_test#mock_login', as: 'auth_test_mock_login'
    get '/auth/test/mock_login_as/:user', to: 'auth_test#mock_login_as', as: 'auth_test_mock_login_as'
    get '/auth/test/mock_logout', to: 'auth_test#mock_logout', as: 'auth_test_mock_logout'
  end

  # API routes
  namespace :api do
    namespace :v1 do
      # Health check endpoint
      get 'health', to: 'base#health_check'
      # File management endpoints
      resources :files, only: [:index, :show, :create, :destroy]
    end
  end

  # Root route
  root "home#index"
end
