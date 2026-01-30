Rails.application.routes.draw do
  get "contacts/new"
  get "contacts/create"

  root to: redirect("/ja/u/admin/articles")

  devise_for :users,
    controllers: {
      omniauth_callbacks: "users/omniauth_callbacks",
      sessions: "users/sessions",
      registrations: "users/registrations",
      passwords: "users/passwords",
      confirmations: "users/confirmations"
    }

  get "up" => "rails/health#show", as: :rails_health_check


scope "/:locale", constraints: { locale: /ja|en/ } do
  # root "welcome#index"

  scope "u" do
    get "/:username/search", to: "search#index", as: :user_search
    get "/:username/articles", to: "articles#index", as: :user_articles
    get "/:username/articles/:id", to: "articles#show", as: :user_article
    post "/:username/articles/:article_id/comments", to: "comments#create", as: :user_article_comments
    get ":username/profile", to: "profiles#show", as: :user_profile
    post "/:username/articles/:article_id/likes", to: "likes#create", as: :user_article_likes
    delete "/:username/articles/:article_id/likes", to: "likes#destroy", as: :user_article_like
  end

  get "/terms-of-service", to: "legal#terms_of_service", as: :terms_of_service
  get "/privacy-policy", to: "legal#privacy_policy", as: :privacy_policy
  get "/disclaimer", to: "legal#disclaimer", as: :disclaimer


  resources :contacts, only: [ :new, :create ]
end

namespace :dashboard do
  resources :articles do
    resource :export, only: [ :show ]
    resource :translation, only: %i[show create update destroy new edit]
  end
  resources :comments, only: %i[index show destroy]
  resources :categories
  post "categories", to: "categories#create", defaults: { format: :json }
  resource :preview, only: [ :create ]
  resources :images, only: [ :create ]
  resource :profile, only: %i[edit update]
  resource :blog_setting, only: %i[edit update]
  resources :analytics, only: [ :index ]
  get "account/delete", to: "account#delete_confirmation", as: :delete_account_confirmation
  resources :attachments, only: [ :destroy ]
end

get "/dashboard", to: redirect("/dashboard/articles")
get "/", to: redirect("/ja")

namespace :admin do
  resources :users, only: [ :index, :show, :update ]
  resources :articles, only: [ :index, :destroy ]
  resources :contacts, only: [ :index, :show, :update ]

  root "dashboard#index"
end

if Rails.env.development?
  mount LetterOpenerWeb::Engine, at: "/letter_opener"
end
end
