Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  root 'static_pages#home'

  get 'calendly/auth', to: 'calendly#auth'
  get 'calendly/callback', to: 'calendly#callback'
  post 'calendly/get_token', to: 'calendly#get_token'
  get 'calendly/events', to: 'calendly#events'
  get '/calendly/all', to: 'calendly#all'
  get '/calendly/all_csv', to: 'calendly#all_csv', defaults: { format: 'csv' }

  resources :professionals do
    member do
      delete :destroy, as: :delete
      get :events
      get :events_csv, defaults: { format: 'csv' }
    end
  end

  # Organization routes
  get '/organization/events', to: 'organization#events'
  get '/organization/events_csv', to: 'organization#events_csv', defaults: { format: 'csv' }
end
