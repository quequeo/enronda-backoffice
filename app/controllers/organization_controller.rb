class OrganizationController < ApplicationController
  before_action :authenticate_user!
  before_action :set_calendly_oauth

  def events
    @events = fetch_organization_events
    @total_events = @events&.length || 0
  end

  def events_csv
    @events = fetch_organization_events
    
    respond_to do |format|
      format.csv do
        headers = ['Professional', 'Event Name', 'Start Time', 'End Time', 'Status', 'Created At', 'Event URL']
        
        csv_data = CSV.generate(headers: true) do |csv|
          csv << headers
          
          @events&.each do |event|
            next if event.is_a?(Hash) && event[:error]
            
            csv << [
              event['professional_name'] || 'Unknown',
              event['name'] || 'No Name',
              event['start_time'] || 'N/A',
              event['end_time'] || 'N/A',
              event['status'] || 'N/A',
              event['created_at'] || 'N/A',
              event['uri'] || 'N/A'
            ]
          end
        end
        
        send_data csv_data, filename: "organization_events_#{Date.current}.csv"
      end
    end
  end

  private

  def set_calendly_oauth
    @calendly_oauth = CalendlyOAuth.first
    unless @calendly_oauth&.access_token
      flash[:error] = "No Calendly OAuth token found. Please authenticate first."
      redirect_to root_path and return
    end
  end

  def fetch_organization_events
    return [] unless @calendly_oauth

    begin
      # First, get the organization URI from /users/me endpoint
      user_response = HTTParty.get(
        'https://api.calendly.com/users/me',
        headers: {
          'Authorization' => "Bearer #{@calendly_oauth.access_token}",
          'Content-Type' => 'application/json'
        }
      )

      if user_response.success?
        user_data = JSON.parse(user_response.body)
        organization_uri = user_data.dig('resource', 'current_organization')
        
        if organization_uri
          # Now fetch events using the organization URI
          events_response = HTTParty.get(
            'https://api.calendly.com/scheduled_events',
            query: build_query_params(organization_uri),
            headers: {
              'Authorization' => "Bearer #{@calendly_oauth.access_token}",
              'Content-Type' => 'application/json'
            }
          )

          if events_response.success?
            events_data = JSON.parse(events_response.body)
            events = events_data.dig('collection') || []
            
            # Add professional names to events
            events_with_professionals = add_professional_names(events)
            
            # Sort by start_time (most recent first)
            events_with_professionals.sort_by { |event| event['start_time'] }.reverse
          else
            Rails.logger.error "Failed to fetch events: #{events_response.code} - #{events_response.body}"
            []
          end
        else
          Rails.logger.error "No organization URI found in user data"
          []
        end
      else
        Rails.logger.error "Failed to fetch user data: #{user_response.code} - #{user_response.body}"
        []
      end
    rescue => e
      Rails.logger.error "Error fetching organization events: #{e.message}"
      []
    end
  end

  def build_query_params(organization_uri)
    params = {
      organization: organization_uri,
      count: 100,
      sort: 'start_time:desc'
    }

    # Add date filters if provided
    if params[:start_date].present?
      params[:min_start_time] = params[:start_date].iso8601
    end

    if params[:end_date].present?
      params[:max_start_time] = params[:end_date].iso8601
    end

    # Add status filter if provided
    params[:status] = params[:status] if params[:status].present?

    params
  end

  def add_professional_names(events)
    professionals = Professional.all.index_by(&:organization)
    
    events.map do |event|
      event_uri = event['uri']
      
      if event_uri.present?
        professional = professionals.find { |org, prof| event_uri.include?(org) }&.last
        
        if professional
          event['professional_name'] = professional.name
        else
          event['professional_name'] = 'Unknown'
        end
      else
        event['professional_name'] = 'No URI'
      end
      
      event
    end
  end
end
