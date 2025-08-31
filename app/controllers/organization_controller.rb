class OrganizationController < ApplicationController
  require 'will_paginate/array'
  require 'csv'

  before_action :authenticate_user!
  before_action :set_calendly_oauth, only: [:events, :events_csv]

  def events
    begin
      # Get query parameters
      query_params = build_query_params
      
      # Fetch events from Calendly API
      events_data = fetch_events_from_calendly(query_params)
      
      if events_data && events_data['data']
        @events = events_data['data']
        
        # Apply client-side filtering for status if provided
        if params[:status].present? && params[:status] != 'all'
          @events = @events.select { |event| event['status'] == params[:status] }
        end
        
        # Sort events by start_time (most recent first)
        @events = @events.sort_by { |event| event['start_time'] }.reverse
        
        # Paginate events
        @events = @events.paginate(page: params[:page], per_page: 20)
      else
        @events = []
        flash.now[:error] = "No events found or error fetching events"
      end
    rescue => e
      Rails.logger.error "Calendly error: #{e.message}"
      @events = []
      flash.now[:error] = "Error fetching events: #{e.message}"
    end
  end

  def events_csv
    begin
      # Get query parameters
      query_params = build_query_params
      
      # Fetch events from Calendly API
      events_data = fetch_events_from_calendly(query_params)
      
      if events_data && events_data['data']
        events = events_data['data']
        
        # Apply client-side filtering for status if provided
        if params[:status].present? && params[:status] != 'all'
          events = events.select { |event| event['status'] == params[:status] }
        end
        
        # Sort events by start_time (most recent first)
        events = events.sort_by { |event| event['start_time'] }.reverse
        
        # Generate CSV data
        csv_data = generate_csv_data(events)
        
        send_data csv_data, 
                  filename: "organization_events_#{Date.current}.csv",
                  type: 'text/csv'
      else
        redirect_to organization_events_path, alert: "No events found or error fetching events"
      end
    rescue => e
      Rails.logger.error "Calendly CSV error: #{e.message}"
      redirect_to organization_events_path, alert: "Error generating CSV: #{e.message}"
    end
  end

  private

  def set_calendly_oauth
    @calendly_oauth ||= CalendlyOAuth.last
  end

  def build_query_params
    params = {}
    
    # Add count parameter
    params[:count] = 100
    
    # Add default time range (last 90 days)
    params[:min_start_time] = (Time.now - 90.days).iso8601
    
    # Add date filters if provided
    if params[:start_date].present?
      params[:min_start_time] = Date.parse(params[:start_date]).beginning_of_day.iso8601
    end
    
    if params[:end_date].present?
      params[:max_start_time] = Date.parse(params[:end_date]).end_of_day.iso8601
    end
    
    params.compact
  end

  def fetch_events_from_calendly(query_params)
    access_token = get_access_token
    
    if access_token.nil?
      raise "No access token available"
    end

    # First, get the organization URI from the user's profile
    response_me = HTTParty.get('https://api.calendly.com/users/me',
      headers: { 'Authorization' => "Bearer #{access_token}", 'Content-Type' => 'application/json' }
    )
    
    if response_me.success?
      organization_uri = response_me.parsed_response['resource']['current_organization']
      
      # Update query params with the correct organization URI
      query_params[:organization] = organization_uri
      
      # Make the API request using HTTParty like CalendlyService
      response = HTTParty.get(
        'https://api.calendly.com/scheduled_events',
        headers: {
          'Authorization' => "Bearer #{access_token}",
          'Content-Type' => 'application/json'
        },
        query: query_params
      )

      if response.success?
        response.parsed_response
      else
        raise "API request failed: #{response.code} - #{response.message}"
      end
    else
      raise "Failed to get user profile: #{response_me.code} - #{response_me.message}"
    end
  end

  def get_access_token
    @calendly_oauth&.access_token
  end

  def generate_csv_data(events)
    CSV.generate(headers: true) do |csv|
      csv << ['Event Name', 'Status', 'Start Time', 'End Time', 'Created At', 'Professional']
      
      events.each do |event|
        csv << [
          event['name'],
          event['status'],
          event['start_time'],
          event['end_time'],
          event['created_at'],
          'Organization Event'
        ]
      end
    end
  end
end
