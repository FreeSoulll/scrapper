Rails.application.routes.draw do
  devise_for :users, skip:[:registrations, :passwords]
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
  root 'scrape#index'
  post "products", to: 'scrape#products'
  post "upload_articles", to: 'scrape#upload_articles'
  get "articles", to: 'scrape#articles'
  get "reviews", to: 'scrape#reviews'
  post "categories", to: 'scrape#collect_categories'
  post "change_linlk_in_file", to: 'scrape#change_linlk_in_file'

  resources :shops

  get 'user', to: 'users#index', as: 'user'
end
