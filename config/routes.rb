# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors and load balancers.
  get "up" => "rails/health#show", as: :rails_health_check

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
