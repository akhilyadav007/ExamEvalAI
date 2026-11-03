Rails.application.routes.draw do
  root "exams#index"

  resources :exams do
    resources :answer_books, only: [:new, :create]
  end

  resources :answer_books, only: [:show, :destroy] do
    post :rerun, on: :member
    resources :answers, only: [:update]
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
