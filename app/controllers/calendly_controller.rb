class CalendlyController < ApplicationController

  def welcome
  end

  require 'base64'

  def auth
    @client_id = ENV['CALENDLY_CLIENT_ID']
    @redirect_uri = ENV['CALENDLY_REDIRECT_URI']
    @connect_to_calendly_url = "https://auth.calendly.com/oauth/authorize?client_id=#{@client_id}&response_type=code&redirect_uri=#{@redirect_uri}"
  end

  def callback
    authorization_code = params[:code]
    if authorization_code
      response = get_access_token(authorization_code)

      owner = response['owner'].split('/').last
      organization = response['organization'].split('/').last

      calendly_oauth = CalendlyOAuth.find_or_create_by(owner: owner, organization: organization)
      calendly_oauth.update(access_token: response['access_token'], refresh_token: response['refresh_token'])

      flash[:notice] = "Access Token received"
      render :token
    else
      # Manejar el error de no recibir el código de autorización
      flash[:error] = "Authorization failed"
      redirect_to root_path
    end
  end

  def events
    access_token = CalendlyOAuth.last.access_token
    organization = CalendlyOAuth.last.organization

    if access_token.nil? || organization.nil?
      flash[:error] = "No se ha obtenido el token de acceso o la organización"
      redirect_to root_path
    else
      response = HTTParty.get(
        'https://api.calendly.com/scheduled_events',
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        query: {
          organization: "https://api.calendly.com/organizations/#{organization}",
          count: 100,
          min_start_time: (Time.now - 90.days).iso8601
        }
      )

      if response.success?
        @events = response.parsed_response['collection']
      else
        flash[:error] = "Error al obtener los eventos programados de Calendly: #{response.code} - #{response.message}"
        redirect_to root_path
      end
    end
  end

  private

  def get_access_token(authorization_code)
    client_id = ENV['CALENDLY_CLIENT_ID']
    client_secret = ENV['CALENDLY_CLIENT_SECRET']
    redirect_uri = ENV['CALENDLY_REDIRECT_URI']

    credentials = Base64.strict_encode64("#{client_id}:#{client_secret}")
    headers = {
      'Content-Type' => 'application/x-www-form-urlencoded',
      'Authorization' => "Basic #{credentials}"
    }

    body = {
      grant_type: 'authorization_code',
      code: authorization_code,
      redirect_uri: redirect_uri
    }

    response = HTTParty.post('https://auth.calendly.com/oauth/token', headers: headers, body: body)
    response.parsed_response
  end
end
