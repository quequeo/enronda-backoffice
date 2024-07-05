class CalendlyService
  class << self

    CLIENT_ID = ENV['CALENDLY_CLIENT_ID']
    CLIENT_SECRET = ENV['CALENDLY_CLIENT_SECRET']
    REDIRECT_URI = ENV['CALENDLY_REDIRECT_URI']

    def authorize_url
      return "https://auth.calendly.com/oauth/authorize?client_id=#{CLIENT_ID}&response_type=code&redirect_uri=#{REDIRECT_URI}"
    end

    def callback(params)
      response = get_access_token(params[:code])
      owner = response['owner'].split('/').last
      organization = response['organization'].split('/').last
  
      calendly_oauth = CalendlyOAuth.find_or_create_by(owner: owner, organization: organization)
      calendly_oauth.update(access_token: response['access_token'], refresh_token: response['refresh_token'])
      
      response['access_token']
    end

    def gather_events(params)

      status = params[:status].present? ? params[:status] : nil
      start_date = params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : (Time.now - 30.days)
      end_date = params[:end_date].present? ? Date.parse(params[:end_date]).end_of_day : nil

      events = []

      Professional.all.each do |professional|

        if professional.token.nil?
          events << [{ error: "Please validate token!", professional_name: professional.name }]
          next
        end

        if professional.organization.nil?
          response_me = HTTParty.get('https://api.calendly.com/users/me',
            headers: { 'Authorization' => "Bearer #{professional.token}", 'Content-Type' => 'application/json' },
          )
          
          if response_me.success?
            organization = response_me.parsed_response['resource']['current_organization']
            professional.update(organization: organization)
          else
            events << [{ error: "Please validate token!", professional_name: professional.name }]
            next
          end
        end

        query_params = { organization: professional.organization }
        query_params.merge!(status: status) if status.present?
        query_params.merge!(min_start_time: start_date.iso8601)
        query_params.merge!(max_start_time: end_date.iso8601) if end_date.present?
        query_params.merge!(sort: 'start_time:desc') if status.present? || end_date.present? || start_date.present?

        response_events = HTTParty.get('https://api.calendly.com/scheduled_events',
          headers: { 'Authorization' => "Bearer #{professional.token}", 'Content-Type' => 'application/json' },
          query: query_params
        )
        
        if response_events.success?
          events << response_events.parsed_response['collection']
        else
          events << [{ error: "Please validate token!", professional_name: professional.name }]
        end
      end

      events.flatten
    end
  
    private

    def get_access_token(authorization_code)
      credentials = Base64.strict_encode64("#{CLIENT_ID}:#{CLIENT_SECRET}")
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Authorization' => "Basic #{credentials}"
      }

      body = {
        grant_type: 'authorization_code',
        code: authorization_code,
        redirect_uri: REDIRECT_URI
      }

      response = HTTParty.post('https://auth.calendly.com/oauth/token', headers: headers, body: body)
      response.parsed_response
    end

    def renew_access_token
    end
  end
end