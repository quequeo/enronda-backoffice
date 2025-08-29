Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }

  root 'static_pages#home'
  # get 'static_pages/about'
  # get 'static_pages/contact'
  # get 'static_pages/privacy_policy'
  # get 'static_pages/terms_of_service'

  get 'calendly/auth', to: 'calendly#auth'
  get 'calendly/callback', to: 'calendly#callback'
  post 'calendly/get_token', to: 'calendly#get_token'
  get 'calendly/events', to: 'calendly#events'
  get '/calendly/all', to: 'calendly#all'
  get '/calendly/all_csv', to: 'calendly#all_csv', defaults: { format: 'csv' }

  get '/organization/events', to: 'organization#events'
  get '/organization/events_csv', to: 'organization#events_csv', defaults: { format: 'csv' }
  get '/organization/debug_oauth', to: 'organization#debug_oauth'
  get '/organization/test_api_call', to: 'organization#test_api_call'
  get '/organization/refresh_token', to: 'organization#refresh_token'
  get '/organization/start_auth', to: 'organization#start_auth'

  resources :professionals do
    member do
      delete :destroy, as: :delete
      get :events
      get :events_csv, defaults: { format: 'csv' }
    end
  end
end
