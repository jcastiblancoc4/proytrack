Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  resources :projects, only: [:show, :new, :create, :edit, :update, :destroy] do
    resources :expenses, except: [:show]
    resources :shared_projects, only: [:create, :destroy]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end