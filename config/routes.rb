Rails.application.routes.draw do
  # Devise routes for User authentication
  devise_for :users

  # Pages
  get 'unauthorized', to: 'pages#unauthorized', as: :unauthorized

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    namespace :v1 do
      resources :courses, only: [:index]
      resources :sections, only: [] do
        member do
          get 'calendar', action: :calendar
          get 'preview_class_dates', action: :preview_class_dates
        end
      end
      resources :weekly_plans, only: [:index]
      resources :payment_periods, only: [:index]
      resources :payment_methods, only: [:index]
      resources :enrollments, only: [:create]
      resources :teachers, only: [] do
        member do
          get 'dashboard', action: :dashboard
        end
      end
      resources :users, only: [] do
        collection do
          get 'find_by_email', action: :find_by_email
        end
      end
    end
  end

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    get 'export', to: 'dashboard#export', as: :export_financial_report

    resource :profile, only: [:edit], controller: 'profiles' do
      patch :personal
      patch :password
    end
    resources :courses do
      member do
        get :attendance
        patch :toggle_active
      end
    end
    resources :sections do
      member do
        patch :take_attendance
      end
    end
    resources :enrollments do
      collection do
        get 'sections_by_course', action: :sections_by_course
      end
    end
    resources :enrollment_sections, only: [:edit, :update, :destroy] do
      member do
        get  :makeup
        post :assign_makeup
      end
    end
    resources :users
    resources :weekly_plans
    resources :payment_periods
    resources :payment_methods
    resources :payments do
      collection do
        get 'export', action: :export
      end
    end
    resources :transbank_transactions, only: [:index, :show]
    resources :teacher_payments, only: [:index, :show] do
      member do
        patch :toggle_status
      end
    end
  end

  # Student routes
  namespace :students do
    resources :payments, only: [:index] do
      collection do
        post 'pay_enrollment_fee/:enrollment_id', action: :pay_enrollment_fee, as: :pay_enrollment_fee
      end
    end
  end

  # Transbank routes
  get '/transbank/callback', to: 'transbank#callback', as: :transbank_callback
  post '/transbank/callback', to: 'transbank#callback'
  get '/transbank/result/success', to: 'transbank#success', as: :success_transbank_result
  get '/transbank/result/failure', to: 'transbank#failure', as: :failure_transbank_result

  # Defines the root path route ("/")
  root "admin/dashboard#index"
end
