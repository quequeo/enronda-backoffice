class OrganizationController < ApplicationController
  require 'will_paginate/array'
  require 'csv'

  before_action :set_calendly_oauth, only: [:events]

  def events
    Rails.logger.info "DEBUG: @calendly_oauth present: #{@calendly_oauth.present?}"
    Rails.logger.info "DEBUG: access_token present: #{@calendly_oauth&.access_token.present?}"
    Rails.logger.info "DEBUG: organization present: #{@calendly_oauth&.organization.present?}"
    Rails.logger.info "DEBUG: organization value: #{@calendly_oauth&.organization}"
    
    if @calendly_oauth&.access_token && @calendly_oauth&.organization
      begin
        Rails.logger.info "DEBUG: Building query params..."
        query_params = build_query_params
        Rails.logger.info "DEBUG: Query params: #{query_params}"
        Rails.logger.info "DEBUG: Fetching organization events..."
        response = fetch_organization_events(@calendly_oauth.access_token, query_params)
        Rails.logger.info "DEBUG: Response success: #{response&.success?}"
        Rails.logger.info "DEBUG: Response code: #{response&.code}"
        Rails.logger.info "DEBUG: Response body keys: #{response&.parsed_response&.keys}"

        if response&.success?
          collection = response.parsed_response&.fetch('collection', [])
          # Sort events by start_time in descending order (most recent first)
          collection = collection.sort_by { |event| Time.parse(event['start_time']) }.reverse
          @events_count = collection.count
          @events = collection.paginate(page: params[:page], per_page: 15)
        elsif response&.code == 401
          handle_token_refresh(query_params)
        else
          flash[:error] = "Calendly error: unable to obtain organization events: #{response&.code || 'Unknown'} - #{response&.message || 'Unknown error'}"
          redirect_to root_path
        end
      rescue => e
        Rails.logger.error "Error fetching organization events: #{e.message}"
        flash[:error] = "Calendly error: unable to obtain organization events"
        redirect_to root_path
      end
    else
      Rails.logger.error "DEBUG: Missing OAuth data - access_token: #{@calendly_oauth&.access_token.present?}, organization: #{@calendly_oauth&.organization.present?}"
      flash[:error] = "Calendly error: no access token or organization found. Please check OAuth configuration."
      redirect_to root_path
    end
  end

  def debug_oauth
    @calendly_oauth = CalendlyOAuth.last
    render plain: "OAuth Debug:\n" +
                 "Present: #{@calendly_oauth.present?}\n" +
                 "Access Token: #{@calendly_oauth&.access_token.present?}\n" +
                 "Organization: #{@calendly_oauth&.organization.present?}\n" +
                 "Organization Value: #{@calendly_oauth&.organization}\n"
  end

  def test_api_call
    @calendly_oauth = CalendlyOAuth.last
    query_params = {
      organization: "https://api.calendly.com/organizations/#{@calendly_oauth.organization}",
      count: 10
    }
    
    response = HTTParty.get(
      'https://api.calendly.com/scheduled_events',
      headers: {
        'Authorization' => "Bearer #{@calendly_oauth.access_token}",
        'Content-Type' => 'application/json'
      },
      query: query_params
    )
    
    render plain: "API Test:\n" +
                 "Success: #{response.success?}\n" +
                 "Code: #{response.code}\n" +
                 "Body: #{response.parsed_response}\n"
  end

  def refresh_token
    @calendly_oauth = CalendlyOAuth.last
    
    response = HTTParty.post(
      'https://auth.calendly.com/oauth/token',
      headers: {
        'Content-Type' => 'application/json'
      },
      body: {
        grant_type: 'refresh_token',
        refresh_token: @calendly_oauth.refresh_token,
        client_id: ENV['CALENDLY_CLIENT_ID'],
        client_secret: ENV['CALENDLY_CLIENT_SECRET'],
        redirect_uri: ENV['CALENDLY_REDIRECT_URI']
      }.to_json
    )
    
    if response.success?
      new_token_data = response.parsed_response
      @calendly_oauth.update(
        access_token: new_token_data['access_token'],
        refresh_token: new_token_data['refresh_token']
      )
      render plain: "Token refreshed successfully!\n" +
                   "New access token: #{new_token_data['access_token'][0..20]}...\n" +
                   "New refresh token: #{new_token_data['refresh_token'][0..20]}..."
    else
      render plain: "Failed to refresh token:\n" +
                   "Code: #{response.code}\n" +
                   "Body: #{response.parsed_response}\n\n" +
                   "You need to re-authorize. Go to: /calendly/auth"
    end
  end

  def start_auth
    client_id = ENV['CALENDLY_CLIENT_ID']
    redirect_uri = ENV['CALENDLY_REDIRECT_URI']
    auth_url = "https://auth.calendly.com/oauth/authorize?client_id=#{client_id}&response_type=code&redirect_uri=#{redirect_uri}"
    
    redirect_to auth_url
  end

  def events_csv
    if @calendly_oauth&.access_token && @calendly_oauth&.organization
      begin
        query_params = build_query_params
        response = fetch_organization_events(@calendly_oauth.access_token, query_params)

        if response&.success?
          events = response.parsed_response&.fetch('collection', [])
          # Sort events by start_time in descending order (most recent first)
          events = events.sort_by { |event| Time.parse(event['start_time']) }.reverse
          
          respond_to do |format|
            format.csv do
              send_data generate_csv_data(events), filename: "enronda_organization_events_#{Date.today}.csv"
            end
          end
        else
          flash[:error] = "Calendly error: unable to obtain organization events for CSV export"
          redirect_to organization_events_path
        end
      rescue => e
        Rails.logger.error "Error fetching organization events for CSV: #{e.message}"
        flash[:error] = "Calendly error: unable to obtain organization events for CSV export"
        redirect_to organization_events_path
      end
    else
      flash[:error] = "Calendly error: no access token or organization found"
      redirect_to root_path
    end
  end

  private

  def set_calendly_oauth
    @calendly_oauth ||= CalendlyOAuth.last
  end

  def handle_token_refresh(query_params)
    new_token = renew_access_token(@calendly_oauth.refresh_token)
  
    if new_token
      update_oauth_tokens(new_token)
      response = fetch_organization_events(@calendly_oauth.access_token, query_params)
  
      if response.success?
        @events = response.parsed_response['collection'].paginate(page: params[:page], per_page: 15)
      else
        flash[:error] = "Calendly error: unable to obtain organization events: #{response.code} - #{response.message}"
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
      min_start_time: params[:min_start_time] || (Time.now - 90.days).iso8601,
      max_start_time: params[:max_start_time],
      status: params[:status]
    }.compact
  end

  def fetch_organization_events(access_token, query_params)
    HTTParty.get(
      'https://api.calendly.com/scheduled_events',
      headers: {
        'Authorization' => "Bearer #{access_token}",
        'Content-Type' => 'application/json'
      },
      query: query_params
    )
  end

  def update_oauth_tokens(new_token)
    @calendly_oauth.update(
      access_token: new_token['access_token'],
      refresh_token: new_token['refresh_token']
    )
  end
end
