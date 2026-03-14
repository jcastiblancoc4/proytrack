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

  resources :accounts do
    resources :transactions, only: [:new, :create, :destroy]
  end

  resources :expenses, only: [:index, :create, :edit, :update, :destroy] do
    collection do
      get :export
    end
  end
  resources :expense_categories, only: [:create, :update, :destroy]

  resources :third_parties, only: [:index, :create, :edit, :update, :destroy]

  resources :settlements, only: [:index, :new, :create, :show, :update, :destroy] do
    collection do
      get :preliquidation
    end
    resources :shared_settlements, only: [:create, :destroy]
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end