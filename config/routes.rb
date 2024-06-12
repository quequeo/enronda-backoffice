Rails.application.routes.draw do
  root 'calendly#welcome'

  get 'calendly/auth', to: 'calendly#auth'
  get 'calendly/callback', to: 'calendly#callback'
  post 'calendly/get_token', to: 'calendly#get_token'
  get 'calendly/events'
end
