class CalendlyController < ApplicationController

  require 'base64'
  require 'will_paginate/array'
  require 'csv'

  before_action :set_professional, only: [:index]
  before_action :set_calendly_oauth, only: [:events]

  def auth
    @client_id = ENV['CALENDLY_CLIENT_ID']
    @redirect_uri = ENV['CALENDLY_REDIRECT_URI']
    @connect_to_calendly_url = "https://auth.calendly.com/oauth/authorize?client_id=#{@client_id}&response_type=code&redirect_uri=#{@redirect_uri}"
  end

  def callback
    if params[:code]
      handle_successful_callback
    else
      handle_failed_callback
    end
  end
  
  def all
    puts "all_professional_events"
    sleep(3)
    @events = gather_events
  end

  def all_csv
    respond_to do |format|
      format.csv do
        send_data generate_csv_data, filename: "all_professional_events_#{Date.today}.csv"
      end
    end
  end

  def index
    fetch_professional_events
  end

  def events
    if @calendly_oauth&.access_token && @calendly_oauth&.organization
      puts "fetch organization events"
      sleep(3)
      fetch_organization_events
    else
      handle_missing_oauth_data
    end
    puts "events.present? #{@events.present?}"
    @events = @events || []
  end

  private

  def set_professional
    @professional = Professional.find(params[:professional_id])
  end

  def set_calendly_oauth
    @calendly_oauth = CalendlyOAuth.last
  end

  def handle_successful_callback
    response = get_access_token(params[:code])
    owner = response['owner'].split('/').last
    organization = response['organization'].split('/').last

    calendly_oauth = CalendlyOAuth.find_or_create_by(owner: owner, organization: organization)
    calendly_oauth.update(access_token: response['access_token'], refresh_token: response['refresh_token'])

    flash[:notice] = "Access Token received"
    render :token
  end

  def handle_failed_callback
    flash[:error] = "Authorization failed"
    redirect_to root_path
  end

  def gather_events
    Rails.cache.fetch('all_professional_events', expires_in: 20.minutes) do
      events = []
      Professional.all.each do |professional|
        professional_events = fetch_professional_events(professional)
        events.concat(professional_events) if professional_events.present?
      end
      events.flatten
    end
  end

  def generate_csv_data
    events = gather_events
    CSV.generate do |csv|
      csv << ['Professional Name', 'Event Name', 'Start Time', 'End Time', 'Status']
      
      events.each do |event|
        if event.is_a?(Hash) && event[:error]
          csv << [event[:professional_name], event[:error], '', '', '']
        else
          csv << [
            event['event_memberships'][0]['user_name'],
            event['name'],
            Time.parse(event['created_at']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            Time.parse(event['end_time']).in_time_zone("America/Argentina/Buenos_Aires").strftime("%Y-%m-%d %H:%M"),
            event['status'].capitalize
          ]
        end
      end
    end
  end

  def fetch_professional_events(professional)
    Rails.cache.fetch("professional_events_#{professional.id}", expires_in: 20.minutes) do
      fetch_events_for_single_professional(professional)
    end
  end

  def fetch_events_for_single_professional(professional)
    return [] unless professional.token && professional.organization

    query_params = { 
      count: 50, 
      min_start_time: (Time.now - 30.days).iso8601,
      organization: professional.organization
    }

    response_events = fetch_events(professional, query_params)
    
    if response_events.success?
      response_events.parsed_response['collection']
    else
      [{ error: "Please validate token!", professional_name: professional.name }]
    end
  end

  def fetch_organization_events
    query_params = build_query_params

    Rails.cache.fetch('organization_events', expires_in: 20.minutes) do
      response = fetch_events_from_calendly(@calendly_oauth.access_token, query_params)

      if response.success?
        paginate_events(response.parsed_response['collection'])
      elsif response.code == 401
        handle_expired_token
      else
        handle_calendly_error(response)
      end
    end
  end

  def handle_missing_oauth_data
    flash[:error] = "Calendly error: no access token or organization found"
    redirect_to root_path
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

  def fetch_events(professional, query_params)
    HTTParty.get('https://api.calendly.com/scheduled_events',
      headers: { 'Authorization' => "Bearer #{professional.token}", 'Content-Type' => 'application/json' },
      query: query_params.merge(organization: professional.organization)
    )
  end

  def build_query_params
    {
      organization: "https://api.calendly.com/organizations/#{@calendly_oauth.organization}",
      count: 100,
      min_start_time: (Time.now - 90.days).iso8601,
      status: params[:status],
      min_start_time: params[:min_start_time],
      max_start_time: params[:max_start_time]
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

  def paginate_events(events)
    events.paginate(page: params[:page], per_page: 15)
  end

  def handle_calendly_error(response)
    flash[:error] = "Calendly error: unable to obtain events: #{response.code} - #{response.message}"
    redirect_to root_path
  end
end
