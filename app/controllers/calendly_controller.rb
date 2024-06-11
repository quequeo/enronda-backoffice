class CalendlyController < ApplicationController

  def welcome
  end

  def scheduled_events
    token = ENV['CALENDLY_API_TOKEN']
    response = HTTParty.get('https://api.calendly.com/scheduled_events',
                            headers: {
                              'Authorization' => "Bearer #{token}",
                              'Content-Type' => 'application/json'
                            })

    if response.code == 200
      @scheduled_events = JSON.parse(response.body)
    else
      flash[:error] = "Error al obtener los eventos programados de Calendly: #{response.code} - #{response.message}"
      redirect_to root_path
    end
  end
end
