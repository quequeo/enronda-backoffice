require 'rails_helper'

RSpec.describe CalendlyService, type: :service do
  let(:client_id) { 'test_client_id' }
  let(:client_secret) { 'test_client_secret' }
  let(:redirect_uri) { 'http://localhost:3000/callback' }
  let(:access_token) { 'access_token_123' }
  let(:refresh_token) { 'refresh_token_123' }
  let(:authorization_code) { 'auth_code_123' }

  before do
    # Stub the constants directly since they're evaluated at load time
    stub_const('CalendlyService::CLIENT_ID', client_id)
    stub_const('CalendlyService::CLIENT_SECRET', client_secret)  
    stub_const('CalendlyService::REDIRECT_URI', redirect_uri)
  end

  describe '.authorize_url' do
    it 'returns a valid authorization URL' do
      auth_url = CalendlyService.authorize_url
      expect(auth_url).to include('https://auth.calendly.com/oauth/authorize')
      expect(auth_url).to include('client_id=')
      expect(auth_url).to include('response_type=code')
      expect(auth_url).to include('redirect_uri=')
    end

    it 'includes environment configuration' do
      auth_url = CalendlyService.authorize_url
      expect(auth_url).to include(ENV['CALENDLY_CLIENT_ID']) if ENV['CALENDLY_CLIENT_ID']
      expect(auth_url).to include(ENV['CALENDLY_REDIRECT_URI']) if ENV['CALENDLY_REDIRECT_URI']
    end
  end

  describe '.callback' do
    let(:owner_url) { 'https://api.calendly.com/users/123' }
    let(:organization_url) { 'https://api.calendly.com/organizations/456' }
    let(:oauth_response) {
      {
        'access_token' => access_token,
        'refresh_token' => refresh_token,
        'owner' => owner_url,
        'organization' => organization_url
      }
    }

    before do
      allow(CalendlyService).to receive(:get_access_token).and_return(oauth_response)
    end

    context 'when successful' do
      it 'creates or updates CalendlyOAuth record' do
        expect {
          CalendlyService.callback({ code: authorization_code })
        }.to change(CalendlyOAuth, :count).by(1)

        oauth = CalendlyOAuth.last
        expect(oauth.owner).to eq('123')
        expect(oauth.organization).to eq('456')
        expect(oauth.access_token).to eq(access_token)
        expect(oauth.refresh_token).to eq(refresh_token)
      end

      it 'returns the access token' do
        result = CalendlyService.callback({ code: authorization_code })
        expect(result).to eq(access_token)
      end

      it 'updates existing record instead of creating new one' do
        existing = create(:calendly_o_auth, owner: '123', organization: '456')
        
        expect {
          CalendlyService.callback({ code: authorization_code })
        }.not_to change(CalendlyOAuth, :count)

        existing.reload
        expect(existing.access_token).to eq(access_token)
        expect(existing.refresh_token).to eq(refresh_token)
      end
    end

    context 'when get_access_token fails' do
      before do
        allow(CalendlyService).to receive(:get_access_token).and_return(nil)
      end

      it 'returns nil' do
        result = CalendlyService.callback({ code: authorization_code })
        expect(result).to be_nil
      end

      it 'does not create CalendlyOAuth record' do
        expect {
          CalendlyService.callback({ code: authorization_code })
        }.not_to change(CalendlyOAuth, :count)
      end
    end
  end

  describe '.gather_events' do
    let!(:professional1) { create(:professional, name: 'John Doe') }
    let!(:professional2) { create(:professional, name: 'Jane Smith') }
    let(:events1) { [{ 'name' => 'Event 1', 'status' => 'active' }] }
    let(:events2) { [{ 'name' => 'Event 2', 'status' => 'active' }] }

    before do
      allow(CalendlyService).to receive(:fetch_professional_events)
        .with(professional1, anything).and_return(events1)
      allow(CalendlyService).to receive(:fetch_professional_events)
        .with(professional2, anything).and_return(events2)
    end

    it 'fetches events for all professionals' do
      result = CalendlyService.gather_events({})
      
      expect(result).to eq(events1 + events2)
      expect(CalendlyService).to have_received(:fetch_professional_events).twice
    end

    it 'passes filter options to fetch_professional_events' do
      params = { status: 'active', start_date: '2024-01-01', end_date: '2024-01-31' }
      
      CalendlyService.gather_events(params)
      
      expect(CalendlyService).to have_received(:fetch_professional_events).twice
      # Check that the method was called with parsed date options
      expect(CalendlyService).to have_received(:fetch_professional_events).with(
        professional1, hash_including(status: 'active')
      )
    end

    it 'handles empty professional list' do
      Professional.destroy_all
      result = CalendlyService.gather_events({})
      expect(result).to eq([])
    end
  end

  describe '.professional_events' do
    let(:professional) { create(:professional) }
    let(:params) { { status: 'active' } }
    let(:expected_events) { [{ 'name' => 'Event 1' }] }

    before do
      allow(CalendlyService).to receive(:fetch_professional_events).and_return(expected_events)
    end

    it 'delegates to fetch_professional_events' do
      result = CalendlyService.professional_events(professional, params)
      
      expect(result).to eq(expected_events)
      expect(CalendlyService).to have_received(:fetch_professional_events).with(professional, anything)
    end
  end

  describe '.renew_access_token' do
    let(:new_access_token) { 'new_access_token_456' }
    let(:new_refresh_token) { 'new_refresh_token_456' }
    let(:success_response) {
      double('response', 
        success?: true, 
        parsed_response: {
          'access_token' => new_access_token,
          'refresh_token' => new_refresh_token
        }
      )
    }
    let(:failure_response) { double('response', success?: false) }

    context 'when successful' do
      before do
        allow(HTTParty).to receive(:post).and_return(success_response)
      end

      it 'returns the parsed response' do
        result = CalendlyService.renew_access_token(refresh_token)
        
        expect(result['access_token']).to eq(new_access_token)
        expect(result['refresh_token']).to eq(new_refresh_token)
      end

      it 'makes correct API call' do
        CalendlyService.renew_access_token(refresh_token)
        
        expect(HTTParty).to have_received(:post).with(
          'https://auth.calendly.com/oauth/token',
          hash_including(
            headers: { 'Content-Type' => 'application/json' },
            body: include('"grant_type":"refresh_token"')
          )
        )
      end
    end

    context 'when unsuccessful' do
      before do
        allow(HTTParty).to receive(:post).and_return(failure_response)
      end

      it 'returns nil' do
        result = CalendlyService.renew_access_token(refresh_token)
        expect(result).to be_nil
      end
    end
  end

  describe 'private methods' do
    describe '.parse_date_params' do
      let(:params) do
        {
          status: 'active',
          start_date: '2024-01-15',
          end_date: '2024-01-31'
        }
      end

      it 'parses valid date parameters' do
        result = CalendlyService.send(:parse_date_params, params)
        
        expect(result[:status]).to eq('active')
        expect(result[:start_date]).to eq(Date.parse('2024-01-15').beginning_of_day)
        expect(result[:end_date]).to eq(Date.parse('2024-01-31').end_of_day)
      end

      it 'handles missing date parameters' do
        result = CalendlyService.send(:parse_date_params, { status: 'active' })
        
        expect(result[:status]).to eq('active')
        expect(result[:start_date]).to be_nil
        expect(result[:end_date]).to be_nil
      end

      it 'handles empty status' do
        result = CalendlyService.send(:parse_date_params, { status: '' })
        expect(result[:status]).to be_nil
      end

      it 'handles invalid date format gracefully' do
        params_with_invalid_date = { start_date: 'invalid-date' }
        
        expect {
          CalendlyService.send(:parse_date_params, params_with_invalid_date)
        }.not_to raise_error
      end
    end

    describe '.validate_and_setup_professional' do
      context 'when professional has no token' do
        let(:professional) { build(:professional, token: nil, name: 'Test Professional') }

        it 'returns error event' do
          result = CalendlyService.send(:validate_and_setup_professional, professional)
          
          expect(result[:error]).to eq('Error: missing token!')
          expect(result[:professional_name]).to eq('Test Professional')
        end
      end

      context 'when professional has token but no organization' do
        let(:professional) { create(:professional, :without_organization) }
        let(:user_info_response) do
          double('response',
            success?: true,
            parsed_response: {
              'resource' => {
                'current_organization' => 'https://api.calendly.com/organizations/org123'
              }
            }
          )
        end

        before do
          allow(CalendlyService).to receive(:fetch_user_info).and_return(user_info_response)
        end

        it 'sets up organization and returns nil (no error)' do
          result = CalendlyService.send(:validate_and_setup_professional, professional)
          
          expect(result).to be_nil
          professional.reload
          expect(professional.organization).to eq('https://api.calendly.com/organizations/org123')
        end
      end

      context 'when professional has token and organization' do
        let(:professional) { create(:professional) }

        it 'returns nil (no error)' do
          result = CalendlyService.send(:validate_and_setup_professional, professional)
          expect(result).to be_nil
        end
      end
    end

    describe '.build_query_params' do
      let(:organization) { 'https://api.calendly.com/organizations/org123' }
      let(:filter_options) do
        {
          status: 'active',
          start_date: Time.zone.parse('2024-01-15'),
          end_date: Time.zone.parse('2024-01-31')
        }
      end

      it 'builds complete query parameters' do
        result = CalendlyService.send(:build_query_params, organization, filter_options)
        
        expect(result[:organization]).to eq(organization)
        expect(result[:count]).to eq(100)
        expect(result[:status]).to eq('active')
        expect(result[:min_start_time]).to eq(filter_options[:start_date].iso8601)
        expect(result[:max_start_time]).to eq(filter_options[:end_date].iso8601)
        expect(result[:sort]).to eq('start_time:desc')
      end

      it 'handles minimal filter options' do
        minimal_options = { status: nil, start_date: nil, end_date: nil }
        
        result = CalendlyService.send(:build_query_params, organization, minimal_options)
        
        expect(result[:organization]).to eq(organization)
        expect(result[:count]).to eq(100)
        expect(result[:min_start_time]).to be_present # Default start date
        expect(result).not_to have_key(:status)
        expect(result).not_to have_key(:max_start_time)
        expect(result).not_to have_key(:sort)
      end
    end

    describe '.extract_id_from_url' do
      it 'extracts ID from Calendly URL' do
        url = 'https://api.calendly.com/users/123456'
        result = CalendlyService.send(:extract_id_from_url, url)
        expect(result).to eq('123456')
      end

      it 'handles nil URL' do
        result = CalendlyService.send(:extract_id_from_url, nil)
        expect(result).to be_nil
      end

      it 'handles malformed URL' do
        result = CalendlyService.send(:extract_id_from_url, 'malformed')
        expect(result).to eq('malformed')
      end
    end

    describe '.create_error_event' do
      it 'creates error event hash' do
        result = CalendlyService.send(:create_error_event, 'Test error', 'John Doe')
        
        expect(result).to eq({
          error: 'Test error',
          professional_name: 'John Doe'
        })
      end
    end
  end

  describe 'integration scenarios' do
    let(:professional) { create(:professional) }
    
    before do
      # Stub external API calls
      allow(HTTParty).to receive(:get).and_return(
        double('response', 
          success?: true,
          parsed_response: { 'collection' => [{ 'name' => 'Test Event' }] }
        )
      )
    end

    it 'successfully processes professional with valid token and organization' do
      filter_options = { status: 'active' }
      
      result = CalendlyService.send(:fetch_professional_events, professional, filter_options)
      
      expect(result).to eq([{ 'name' => 'Test Event' }])
      expect(HTTParty).to have_received(:get).with(
        'https://api.calendly.com/scheduled_events',
        hash_including(
          headers: hash_including('Authorization' => "Bearer #{professional.token}"),
          query: hash_including(organization: professional.organization)
        )
      )
    end
  end
end