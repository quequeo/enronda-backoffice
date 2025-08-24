class CalendlyService
  class << self
    # Constants
    CLIENT_ID = ENV['CALENDLY_CLIENT_ID']
    CLIENT_SECRET = ENV['CALENDLY_CLIENT_SECRET']
    REDIRECT_URI = ENV['CALENDLY_REDIRECT_URI']
    
    BASE_API_URL = 'https://api.calendly.com'
    OAUTH_BASE_URL = 'https://auth.calendly.com'
    
    DEFAULT_DAYS_BACK = 30
    MAX_EVENTS_COUNT = 100
    
    # Public API methods
    def authorize_url
      "#{OAUTH_BASE_URL}/oauth/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URI}"
    end

    def callback(params)
      response = get_access_token(params[:code])
      return nil unless response

      owner = extract_id_from_url(response['owner'])
      organization = extract_id_from_url(response['organization'])
  
      calendly_oauth = CalendlyOAuth.find_or_create_by(owner: owner, organization: organization)
      calendly_oauth.update(
        access_token: response['access_token'], 
        refresh_token: response['refresh_token']
      )
      
      response['access_token']
    end

    def gather_events(params)
      filter_options = parse_date_params(params)
      events = []

      Professional.find_each do |professional|
        professional_events = fetch_professional_events(professional, filter_options)
        events.concat(professional_events)
      end

      events
    end

    def professional_events(professional, params)
      filter_options = parse_date_params(params)
      fetch_professional_events(professional, filter_options)
    end

    def renew_access_token(refresh_token)
      response = HTTParty.post(
        "#{OAUTH_BASE_URL}/oauth/token",
        headers: oauth_headers,
        body: refresh_token_body(refresh_token).to_json
      )
      
      response.success? ? response.parsed_response : nil
    end
  
    private

    # OAuth and token management
    def get_access_token(authorization_code)
      response = HTTParty.post(
        "#{OAUTH_BASE_URL}/oauth/token", 
        headers: basic_auth_headers,
        body: authorization_body(authorization_code)
      )
      
      response.success? ? response.parsed_response : nil
    end

    def refresh_token_body(refresh_token)
      {
        grant_type: 'refresh_token',
        refresh_token: refresh_token,
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        redirect_uri: REDIRECT_URI
      }
    end

    def authorization_body(authorization_code)
      {
        grant_type: 'authorization_code',
        code: authorization_code,
        redirect_uri: REDIRECT_URI
      }
    end

    # Professional validation and setup
    def validate_and_setup_professional(professional)
      return create_error_event("Error: missing token!", professional.name) if professional.token.blank?
      
      if professional.organization.blank?
        setup_organization_for_professional(professional)
      else
        nil # No error, professional is ready
      end
    end

    def setup_organization_for_professional(professional)
      response = fetch_user_info(professional.token)
      
      if response&.success?
        organization = response.parsed_response.dig('resource', 'current_organization')
        professional.update(organization: organization)
        nil # Success
      else
        create_error_event("Please, validate token!", professional.name)
      end
    end

    def fetch_user_info(token)
      HTTParty.get(
        "#{BASE_API_URL}/users/me",
        headers: bearer_auth_headers(token)
      )
    rescue => e
      Rails.logger.error "Error fetching user info: #{e.message}"
      nil
    end

    # Events fetching
    def fetch_professional_events(professional, filter_options)
      error = validate_and_setup_professional(professional)
      return [error] if error

      query_params = build_query_params(professional.organization, filter_options)
      response = fetch_events_from_api(professional.token, query_params)
      
      if response&.success?
        response.parsed_response['collection'] || []
      else
        [create_error_event("Please validate token!", professional.name)]
      end
    end

    def fetch_events_from_api(token, query_params)
      HTTParty.get(
        "#{BASE_API_URL}/scheduled_events",
        headers: bearer_auth_headers(token),
        query: query_params
      )
    rescue => e
      Rails.logger.error "Error fetching events from API: #{e.message}"
      nil
    end

    # Parameter parsing and building
    def parse_date_params(params)
      {
        status: params[:status].presence,
        start_date: parse_date_or_default(params[:start_date]),
        end_date: parse_date_or_default(params[:end_date], is_end_date: true)
      }
    end

    def parse_date_or_default(date_string, is_end_date: false)
      return nil if date_string.blank?
      
      date = Date.parse(date_string)
      is_end_date ? date.end_of_day : date.beginning_of_day
    rescue ArgumentError
      default_start_date
    end

    def default_start_date
      Time.current - DEFAULT_DAYS_BACK.days
    end

    def build_query_params(organization, filter_options)
      params = {
        organization: organization,
        count: MAX_EVENTS_COUNT,
        min_start_time: (filter_options[:start_date] || default_start_date).iso8601
      }
      
      params[:status] = filter_options[:status] if filter_options[:status]
      params[:max_start_time] = filter_options[:end_date].iso8601 if filter_options[:end_date]
      params[:sort] = 'start_time:desc' if should_sort?(filter_options)
      
      params
    end

    def should_sort?(filter_options)
      filter_options[:status] || filter_options[:end_date] || filter_options[:start_date]
    end

    # Headers
    def basic_auth_headers
      credentials = Base64.strict_encode64("#{CLIENT_ID}:#{CLIENT_SECRET}")
      {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Authorization' => "Basic #{credentials}"
      }
    end

    def oauth_headers
      {
        'Content-Type' => 'application/json'
      }
    end

    def bearer_auth_headers(token)
      {
        'Authorization' => "Bearer #{token}",
        'Content-Type' => 'application/json'
      }
    end

    # Utility methods
    def extract_id_from_url(url)
      url&.split('/')&.last
    end

    def create_error_event(message, professional_name)
      { error: message, professional_name: professional_name }
    end
  end
end