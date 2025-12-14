Rails.application.routes.draw do
  root "home#index"

  devise_for :users

  resources :projects, only: [:show, :new, :create, :edit, :update, :destroy] do
    member do
      patch :update_status
    end
    resources :expenses, except: [:show]
    resources :shared_projects, only: [:create, :destroy]
  end

  resources :settlements, only: [:index, :new, :create, :show, :destroy] do
    collection do
      get :preliquidation
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end