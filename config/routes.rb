Rails.application.routes.draw do
  root 'calendly#welcome'
  get 'calendly/scheduled_events'
end
