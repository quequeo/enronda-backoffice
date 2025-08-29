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

  get '/organization/events', to: 'organization#events'
  get '/organization/events_csv', to: 'organization#events_csv', defaults: { format: 'csv' }

  resources :professionals do
    member do
      delete :destroy, as: :delete
      get :events
      get :events_csv, defaults: { format: 'csv' }
    end
  end
end
