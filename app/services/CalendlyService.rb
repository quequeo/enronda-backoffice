class CalendlyService
  def self.auth
    client_id = ENV['CALENDLY_CLIENT_ID']
    redirect_uri = ENV['CALENDLY_REDIRECT_URI']
    return "https://auth.calendly.com/oauth/authorize?client_id=#{client_id}&response_type=code&redirect_uri=#{redirect_uri}"
  end

end