Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :courses, only: [:index]
      resources :payment_plans, only: [:index]
      resources :payment_methods, only: [:index]
      resources :enrollments, only: [:create]
    end
  end

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    resources :courses
    resources :sections
    resources :enrollments, only: [:index, :show, :destroy]
    resources :users
    resources :payment_plans
    resources :payment_methods
  end

  # Defines the root path route ("/")
  root "admin/dashboard#index"
end
