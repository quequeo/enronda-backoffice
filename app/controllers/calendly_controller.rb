class CalendlyController < ApplicationController

  def welcome
  end

  def scheduled_events
    byebug
    token = 'eyJraWQiOiIxY2UxZTEzNjE3ZGNmNzY2YjNjZWJjY2Y4ZGM1YmFmYThhNjVlNjg0MDIzZjdjMzJiZTgzNDliMjM4MDEzNWI0IiwidHlwIjoiUEFUIiwiYWxnIjoiRVMyNTYifQ.eyJpc3MiOiJodHRwczovL2F1dGguY2FsZW5kbHkuY29tIiwiaWF0IjoxNzE4MTM4MDA5LCJqdGkiOiIzYmI2NmRjNi0zNzdkLTRhODEtYjRmZS0wM2M1MGMwMGYxMWYiLCJ1c2VyX3V1aWQiOiJmZWU0MmY2Zi0wNDNkLTQwMmEtYjM2MS1lMDdhNTdiYjhjM2EifQ.L7ROV_TzVwzXuOmQCqDwESdf76kOZ0kOFEF73zmBzljSFC8-x0Iu3Js-xbqWKEUhYnsYW3shUDlFBIDSAlj0Iw'

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
