require 'rails_helper'

# Solo correr estos tests si hay tokens reales disponibles
RSpec.describe 'Calendly API Integration', type: :integration, skip: ENV['CALENDLY_REAL_TOKEN'].blank? do
  let(:real_token) { ENV['CALENDLY_REAL_TOKEN'] }
  let(:professional) { create(:professional, token: real_token) }

  describe 'Real API calls' do
    it 'can fetch user info from Calendly API', :vcr do
      VCR.use_cassette('calendly_user_info') do
        response = HTTParty.get(
          'https://api.calendly.com/users/me',
          headers: {
            'Authorization' => "Bearer #{real_token}",
            'Content-Type' => 'application/json'
          }
        )
        
        expect(response.code).to eq(200)
        expect(response.parsed_response['resource']).to have_key('current_organization')
      end
    end

    it 'can fetch events from Calendly API', :vcr do
      VCR.use_cassette('calendly_events') do
        events = CalendlyService.professional_events(professional, {})
        
        expect(events).to be_an(Array)
        # No debería haber errores si el token es válido
        expect(events.any? { |event| event.is_a?(Hash) && event[:error] }).to be_falsey
      end
    end

    it 'handles token refresh correctly', :vcr do
      # Test solo si tenemos refresh token
      skip unless ENV['CALENDLY_REAL_REFRESH_TOKEN']
      
      VCR.use_cassette('calendly_token_refresh') do
        refresh_token = ENV['CALENDLY_REAL_REFRESH_TOKEN']
        result = CalendlyService.renew_access_token(refresh_token)
        
        expect(result).to have_key('access_token')
        expect(result['access_token']).to be_present
      end
    end
  end
end