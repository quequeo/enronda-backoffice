class CalendlyController < ApplicationController

  require 'base64'
  require 'will_paginate/array'
  require 'csv'

  before_action :set_calendly_oauth, only: [:events]

  def auth
    @connect_to_calendly_url = CalendlyService.authorize_url
  end

  def callback
    CalendlyService.callback(params)
    redirect_to root_path
  end
  
  def all
    filter_params = params.permit!.slice(:status, :start_date, :end_date)
    cache_key = "all_professional_events_#{filter_params.to_param}"

    unless Rails.env.production?
      @events = Rails.cache.read(cache_key) 
      @events = nil if params[:refresh] # force cache refresh
    end

    @events = CalendlyService.gather_events(filter_params) if @events.nil?

    # Sort events by start_time (most recent first) and filter out error entries
    if @events.present?
      valid_events = @events.reject { |event| event.is_a?(Hash) && event[:error] }
      @events = valid_events.sort_by { |event| event['start_time'] }.reverse
    end

    unless Rails.env.production? && @events.present?
      Rails.cache.write(cache_key, @events, expires_in: 4.hour)
    end

    @events
  end

  def all_csv
    filter_params = params.permit!.slice(:status, :start_date, :end_date)

    events = CalendlyService.gather_events(filter_params)

    # Sort events by start_time (most recent first) and filter out error entries
    if events.present?
      valid_events = events.reject { |event| event.is_a?(Hash) && event[:error] }
      events = valid_events.sort_by { |event| event['start_time'] }.reverse
    end

    respond_to do |format|
      format.csv do
        send_data generate_csv_data(events), filename: "professional_events_#{Date.today}.csv"
      end
    end
  end

  def events
    if @calendly_oauth&.access_token && @calendly_oauth&.organization
      query_params = build_query_params
      response = fetch_events_from_calendly(@calendly_oauth.access_token, query_params)

      if response.success?
          @events_count = response.parsed_response['collection'].count
          @events = response.parsed_response['collection'].paginate(page: params[:page], per_page: 15)
      elsif response.code == 401
        handle_token_refresh(query_params)
      else
        flash[:error] = "Calendly error: unable to obtain events: #{response.code} - #{response.message}"
        redirect_to root_path
      end
    else
      flash[:error] = "Calendly error: no access token or organization found"
      redirect_to root_path
    end
  end

  private

  def set_professional
    @professional = Professional.find(params[:professional_id])
  end

  def set_calendly_oauth
    @calendly_oauth ||= CalendlyOAuth.last
  end

  def handle_token_refresh(query_params)
    new_token = renew_access_token(@calendly_oauth.refresh_token)
  
    if new_token
      update_oauth_tokens(new_token)
      response = fetch_events_from_calendly(@calendly_oauth.access_token, query_params)
  
      if response.success?
        @events = response.parsed_response['collection'].paginate(page: params[:page], per_page: 15)
      else
        flash[:error] = "Calendly error: unable to obtain events: #{response.code} - #{response.message}"
        redirect_to root_path
      end
    else
      flash[:error] = "Calendly error: unable to renew access token"
      redirect_to root_path
    end
  end

  def generate_csv_data(events)
    CSV.generate do |csv|
      csv << ['Professional Name', 'Event Name', 'Created At', 'Start Time', 'End Time', 'Status']
      
      events.each do |event|
        if event.is_a?(Hash) && event[:error]
          csv << [event[:professional_name], event[:error], 'N/A', 'N/A', 'N/A', 'N/A']
        else
          csv << [
            event['event_memberships'][0]['user_name'],
            event['name'],
            Time.parse(event['created_at']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            Time.parse(event['start_time']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            Time.parse(event['end_time']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            event['status'].capitalize
          ]
        end
      end
    end
  end

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

  def build_query_params
    {
      organization: "https://api.calendly.com/organizations/#{@calendly_oauth.organization}",
      count: 100,
      min_start_time: (Time.now - 90.days).iso8601,
      status: params[:status],
      min_start_time: params[:min_start_time],
      max_start_time: params[:max_start_time],
      sort: 'start_time:desc'
    }.compact
  end

  def fetch_events_from_calendly(access_token, query_params)
    HTTParty.get(
      'https://api.calendly.com/scheduled_events',
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      },
      query: query_params
    )
  end

  def handle_expired_token
    new_token = renew_access_token(@calendly_oauth.refresh_token)
    if new_token
      update_oauth_tokens(new_token)
      fetch_organization_events
    else
      flash[:error] = "Calendly error: unable to renew access token"
      redirect_to root_path
    end
  end

  def update_oauth_tokens(new_token)
    @calendly_oauth.update(
      access_token: new_token['access_token'],
      refresh_token: new_token['refresh_token']
    )
  end
end
