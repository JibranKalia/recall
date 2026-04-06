Rails.application.routes.draw do
  root "projects#index"

  resources :projects, only: [:index, :show]
  resources :sessions, only: [:show] do
    get :markdown, on: :member
    post :regenerate_title, on: :member
  end
  get "search", to: "search#index"

  resources :experiments, only: [:index, :show, :new, :create] do
    post :add_provider, on: :member
    post :rerun, on: :member
  end

  post "import", to: "imports#create"

  get "up" => "rails/health#show", as: :rails_health_check
end
