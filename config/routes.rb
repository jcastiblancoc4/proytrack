Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  resources :projects, only: [:show, :new, :create, :edit, :update, :destroy] do
    resources :expenses, except: [:show]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end