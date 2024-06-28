class CalendlyController < ApplicationController

  require 'base64'
  require 'will_paginate/array'

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
  
  def all
    @events = []
    @professionals = Professional.all
    @professionals.each do |professional|
      next unless professional.token
  
      response_me = HTTParty.get('https://api.calendly.com/users/me',
        headers: { 'Authorization' => "Bearer #{token = professional.token}", 'Content-Type' => 'application/json' }
      )

      query_params = {
        organization: response_me['resource']['current_organization'],
        count: 50,
        min_start_time: (Time.now - 30.days).iso8601
      }

      if response_me.success?
        response_events = HTTParty.get('https://api.calendly.com/scheduled_events',
          headers: { 'Authorization' => "Bearer #{professional.token}", 'Content-Type' => 'application/json' },
          query: query_params
        )

        if response_events.success?
          events_collection = response_events.parsed_response['collection']
          @events << events_collection
        else
          @events << "Calendly error: unable to obtain scheduled events from #{professional.name}"
        end

      else
        @events << "Calendly error: unable to obtain scheduled events from #{professional.name}"
      end
    end

    @events = @events.flatten
  end

  def index
    @professional = Professional.find(params[:professional_id])

    start_date = params[:start_date].presence || "2023-10-01"
    end_date = params[:end_date] || Time.now.strftime('%Y-%m-%d')

    response_me = HTTParty.get('https://api.calendly.com/users/me',
      headers: { 'Authorization' => "Bearer #{token = @professional.token}", 'Content-Type' => 'application/json' }
    )

    if response_me.success?
      response_events = HTTParty.get('https://api.calendly.com/scheduled_events',
        headers: { 'Authorization' => "Bearer #{@professional.token}", 'Content-Type' => 'application/json' },
        query: { organization: response_me['resource']['current_organization'], min_start_time: start_date, max_start_time: end_date }
      )

      if response_events.success?
        @events = response_events.parsed_response['collection']
        @events = @events.paginate(page: params[:page], per_page: 15)
      else
        flash[:error] = "Calendly error: unable to obtain events: #{response_events.code} - #{response_events.message}"
        redirect_to root_path
      end
    else
      flash[:error] = "Calendly error: unable to obtain scheduled events: #{response.code} - #{response.message}"
      redirect_to root_path
    end
  end

  def events
    calendly_oauth = CalendlyOAuth.last
    access_token = calendly_oauth&.access_token
    organization = calendly_oauth&.organization

    if access_token.nil? || organization.nil?
      flash[:error] = "Calendly error: no access token or organization found"
      redirect_to root_path
    else

      query_params = {
        organization: "https://api.calendly.com/organizations/#{organization}",
        count: 100,
        min_start_time: (Time.now - 90.days).iso8601
      }

      query_params[:status] = params[:status] unless params[:status].blank?
      query_params[:min_start_time] = params[:min_start_time] unless params[:min_start_time].blank?
      query_params[:max_start_time] = params[:max_start_time] unless params[:max_start_time].blank?

      response = HTTParty.get(
        'https://api.calendly.com/scheduled_events',
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        query: query_params
      )

      if response.success?
        @events = response.parsed_response['collection']
        @events = @events.paginate(page: params[:page], per_page: 15)
      elsif response.code == 401
        new_token = renew_access_token(calendly_oauth.refresh_token)
        if new_token
          calendly_oauth.update(
            access_token: new_token['access_token'],
            refresh_token: new_token['refresh_token']
          )
  
          response = HTTParty.get('https://api.calendly.com/scheduled_events',
            headers: { 'Authorization' => "Bearer #{new_token['access_token']}", 'Content-Type' => 'application/json' },
            query: query_params
          )
  
          if response.success?
            @events = response.parsed_response['collection']
            @events = @events.paginate(page: params[:page], per_page: 15)
          else
            flash[:error] = "Calendly error: unable to obtain scheduled events: #{response.code} - #{response.message}"
            redirect_to root_path
          end
        else
          flash[:error] = "Calendly error: unable to renew access token"
          redirect_to root_path
        end
      else
        flash[:error] = "Calendly error: unable to obtain scheduled events: #{response.code} - #{response.message}"
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

  def renew_access_token(refresh_token)
    client_id = ENV['CALENDLY_CLIENT_ID']
    client_secret = ENV['CALENDLY_CLIENT_SECRET']
    redirect_uri = ENV['CALENDLY_REDIRECT_URI']
  
    response = HTTParty.post(
      'https://auth.calendly.com/oauth/token',
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: client_id,
        client_secret: client_secret,
        redirect_uri: redirect_uri
      }.to_json
    )
  
    if response.success?
      response.parsed_response
    else
      nil
    end
  end
end
