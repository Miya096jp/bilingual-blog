Rails.application.routes.draw do
  get "contacts/new"
  get "contacts/create"
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

# Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
# get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
# get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

# Defines the root path route ("/")
# root "posts#index"



# scope "/:locale", constraints: { locale: /ja|en/ } do
#   root "home#index"
#
#   get "/:username/articles", to: "articles#index", constraints: { username: /[^\/]+/ }, as: :user_articles
#   get "/:username/articles/:id", to: "articles#show", constraints: { username: /[^\/]+/ }, as: :user_article
#   post "/:username/articles/:article_id/comments", to: "comments#create", constraints: { username: /[^\/]+/ }, as: :user_article_comments
#   get "search", to: "search#index"
#   get ":username/profile", to: "profile#show", constraints: { username: /[^\/]+/ }, as: :user_profile
# end


scope "/:locale", constraints: { locale: /ja|en/ } do
  root "welcome#index"

  scope "u" do
    get "/:username/search", to: "search#index", as: :user_search
    get "/:username/articles", to: "articles#index", as: :user_articles
    get "/:username/articles/:id", to: "articles#show", as: :user_article
    post "/:username/articles/:article_id/comments", to: "comments#create", as: :user_article_comments
    get ":username/profile", to: "profiles#show", as: :user_profile
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
end

get "/dashboard", to: redirect("/dashboard/articles")
get "/", to: redirect("/ja")

namespace :admin do
  resources :users, only: [ :index, :show, :update ]
  resources :articles, only: [ :index, :destroy ]
  resources :contacts, only: [ :index, :show, :update ]

  root "dashboard#index"
end
end
