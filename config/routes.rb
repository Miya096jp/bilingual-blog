Rails.application.routes.draw do
  devise_for :users
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
  root "home#index"
  get "search", to: "search#index"

  scope "u" do
    get "/:username/articles", to: "articles#index", as: :user_articles
    get "/:username/articles/:id", to: "articles#show", as: :user_article
    post "/:username/articles/:article_id/comments", to: "comments#create", as: :user_article_comments
    get ":username/profile", to: "profiles#show", as: :user_profile
  end
end

namespace :dashboard do
  resources :articles do
    resource :translation, only: %i[show create update destroy new edit]
  end
  resources :comments, only: %i[index show destroy]
  # resources :categories, defaults: { format: :html } do
  #   collection do
  #     post "", defaults: { format: :json }
  #   end
  # end

  resources :categories
  post "categories", to: "categories#create", defaults: { format: :json }
  resource :preview, only: [ :create ]
  resources :images, only: [ :create ]
  resource :profile, only: %i[edit update]
  resource :blog_setting, only: %i[edit update]
end

get "/dashboard", to: redirect("/dashboard/articles")
get "/", to: redirect("/ja")
end
