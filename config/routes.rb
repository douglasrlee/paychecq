Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount MissionControl::Jobs::Engine, at: '/jobs'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resource :session
  resources :passwords, param: :token
  resources :users, only: [ :new, :create ]
  resources :transactions
  resource :profile, only: [ :show, :edit, :update ] do
    get :edit_security
    patch :update_security
  end
  resource :settings, only: [ :show ]
  resource :push_subscription, only: [ :create, :destroy ]
  resources :banks, only: [ :create, :destroy ]

  namespace :webhooks do
    resource :plaid, only: [ :create ], controller: 'plaid'
  end

  # Defines the root path route ("/")
  root 'transactions#index'
end
