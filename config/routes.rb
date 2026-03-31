Rails.application.routes.draw do
  root "projects#index"

  resources :projects, only: [:index, :show]
  resources :sessions, only: [:show]
  get "search", to: "search#index"

  get "up" => "rails/health#show", as: :rails_health_check
end
