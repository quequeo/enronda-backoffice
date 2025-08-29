class CalendlyController < ApplicationController
  def auth
    @connect_to_calendly_url = CalendlyService.authorize_url
  end

  def callback
    CalendlyService.callback(params)
    redirect_to root_path
  end
end
