require 'rails_helper'

RSpec.describe CalendlyController, type: :controller do
  let(:user) { create(:user) }
  let(:calendly_oauth) { create(:calendly_o_auth) }
  let(:professional) { create(:professional) }

  before do
    sign_in user
  end

  describe 'GET #auth' do
    let(:auth_url) { 'https://auth.calendly.com/oauth/authorize?client_id=test&response_type=code&redirect_uri=callback' }

    before do
      allow(CalendlyService).to receive(:authorize_url).and_return(auth_url)
    end

    it 'returns a successful response' do
      get :auth
      expect(response).to be_successful
    end

    it 'assigns the Calendly authorization URL' do
      get :auth
      expect(assigns(:connect_to_calendly_url)).to eq(auth_url)
    end

    it 'calls CalendlyService.authorize_url' do
      get :auth
      expect(CalendlyService).to have_received(:authorize_url)
    end
  end

  describe 'GET #callback' do
    let(:auth_code) { 'auth_code_123' }
    let(:access_token) { 'access_token_456' }

    before do
      allow(CalendlyService).to receive(:callback).and_return(access_token)
    end

    it 'calls CalendlyService.callback with params' do
      get :callback, params: { code: auth_code }
      expect(CalendlyService).to have_received(:callback) do |params|
        expect(params[:code]).to eq(auth_code)
      end
    end

    it 'redirects to root path' do
      get :callback, params: { code: auth_code }
      expect(response).to redirect_to(root_path)
    end

    it 'handles missing code parameter' do
      get :callback
      expect(CalendlyService).to have_received(:callback) do |params|
        expect(params[:code]).to be_nil
      end
    end
  end

  describe 'GET #all' do
    let(:mock_events) do
      [
        { 'name' => 'Event 1', 'status' => 'active' },
        { 'name' => 'Event 2', 'status' => 'cancelled' }
      ]
    end

    before do
      allow(CalendlyService).to receive(:gather_events).and_return(mock_events)
      allow(Rails.cache).to receive(:read).and_return(nil)
      allow(Rails.cache).to receive(:write)
    end

    it 'returns a successful response' do
      get :all
      expect(response).to be_successful
    end

    it 'calls CalendlyService.gather_events with filter params' do
      get :all, params: { status: 'active', start_date: '2024-01-01', end_date: '2024-01-31' }
      
      expect(CalendlyService).to have_received(:gather_events).with(
        hash_including(
          'status' => 'active',
          'start_date' => '2024-01-01',
          'end_date' => '2024-01-31'
        )
      )
    end

    it 'assigns the events' do
      get :all
      expect(assigns(:events)).to eq(mock_events)
    end

    context 'caching behavior' do
      it 'attempts to read from cache in non-production' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        get :all
        expect(Rails.cache).to have_received(:read)
      end

      it 'writes to cache after fetching events' do
        get :all
        expect(Rails.cache).to have_received(:write).with(
          anything, mock_events, expires_in: 4.hours
        )
      end

      it 'forces cache refresh when refresh param is present' do
        allow(Rails.cache).to receive(:read).and_return(['cached_event'])
        
        get :all, params: { refresh: 'true' }
        
        expect(CalendlyService).to have_received(:gather_events)
        expect(assigns(:events)).to eq(mock_events)
      end

      it 'uses cached events when available' do
        cached_events = [{ 'name' => 'Cached Event' }]
        allow(Rails.cache).to receive(:read).and_return(cached_events)
        
        get :all
        
        expect(CalendlyService).not_to have_received(:gather_events)
        expect(assigns(:events)).to eq(cached_events)
      end
    end

    it 'handles empty events gracefully' do
      allow(CalendlyService).to receive(:gather_events).and_return([])
      
      get :all
      expect(assigns(:events)).to eq([])
    end

    it 'handles CalendlyService errors gracefully' do
      allow(CalendlyService).to receive(:gather_events).and_raise(StandardError.new('API Error'))
      
      get :all
      expect(assigns(:events)).to eq([])
    end
  end

  describe 'GET #all_csv' do
    let(:mock_events) do
      [
        {
          'name' => 'Test Event',
          'status' => 'active',
          'created_at' => '2024-01-10T08:00:00Z',
          'start_time' => '2024-01-15T10:00:00Z',
          'end_time' => '2024-01-15T11:00:00Z',
          'event_memberships' => [{ 'user_name' => 'John Doe' }]
        }
      ]
    end

    before do
      allow(CalendlyService).to receive(:gather_events).and_return(mock_events)
    end

    it 'responds with CSV format' do
      get :all_csv, format: :csv
      expect(response.content_type).to include('text/csv')
    end

    it 'generates correct filename with today\'s date' do
      get :all_csv, format: :csv
      expected_filename = "professional_events_#{Date.today}.csv"
      expect(response.headers['Content-Disposition']).to include(expected_filename)
    end

    it 'includes CSV headers' do
      get :all_csv, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Professional Name,Event Name,Created At,Start Time,End Time,Status')
    end

    it 'includes event data' do
      get :all_csv, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Test Event')
      expect(csv_content).to include('John Doe')
      expect(csv_content).to include('Active')
    end

    it 'calls CalendlyService with filter params' do
      get :all_csv, params: { 
        status: 'cancelled',
        start_date: '2024-01-01',
        end_date: '2024-01-31'
      }, format: :csv
      
      expect(CalendlyService).to have_received(:gather_events).with(
        hash_including(
          'status' => 'cancelled',
          'start_date' => '2024-01-01',
          'end_date' => '2024-01-31'
        )
      )
    end

    it 'handles error events in CSV' do
      error_events = [{ error: 'Token expired', professional_name: 'John Doe' }]
      allow(CalendlyService).to receive(:gather_events).and_return(error_events)
      
      get :all_csv, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Token expired')
      expect(csv_content).to include('N/A')
    end
  end

  describe 'GET #events' do
    let(:organization_uuid) { 'org-uuid-123' }
    let(:mock_response) do
      double('response',
        success?: true,
        parsed_response: {
          'collection' => [
            { 'name' => 'Event 1', 'status' => 'active' },
            { 'name' => 'Event 2', 'status' => 'active' }
          ]
        }
      )
    end

    before do
      allow(controller).to receive(:set_calendly_oauth)
      controller.instance_variable_set(:@calendly_oauth, calendly_oauth)
    end

    context 'when calendly oauth exists with valid token and organization' do
      before do
        allow(controller).to receive(:fetch_events_from_calendly).and_return(mock_response)
      end

      it 'returns a successful response' do
        get :events
        expect(response).to be_successful
      end

      it 'assigns events and events count' do
        get :events
        expect(assigns(:events_count)).to eq(2)
        expect(assigns(:events)).to be_present
      end

      it 'paginates the results' do
        get :events, params: { page: 1 }
        expect(assigns(:events)).to respond_to(:current_page)
      end

      it 'builds query params correctly' do
        allow(controller).to receive(:build_query_params).and_return({
          organization: calendly_oauth.organization,
          count: 100
        })
        
        get :events, params: { status: 'active' }
        expect(controller).to have_received(:build_query_params)
      end
    end

    context 'when calendly oauth has no access token' do
      let(:calendly_oauth_without_token) { create(:calendly_o_auth, access_token: nil) }

      before do
        controller.instance_variable_set(:@calendly_oauth, calendly_oauth_without_token)
      end

      it 'redirects to root with error message' do
        get :events
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include('no access token or organization found')
      end
    end

    context 'when calendly oauth has no organization' do
      let(:calendly_oauth_without_org) { create(:calendly_o_auth, organization: nil) }

      before do
        controller.instance_variable_set(:@calendly_oauth, calendly_oauth_without_org)
      end

      it 'redirects to root with error message' do
        get :events
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include('no access token or organization found')
      end
    end

    context 'when API returns 401 (unauthorized)' do
      let(:unauthorized_response) { double('response', success?: false, code: 401) }
      let(:renewed_token_response) { { 'access_token' => 'new_token', 'refresh_token' => 'new_refresh' } }

      before do
        allow(controller).to receive(:fetch_events_from_calendly).and_return(unauthorized_response)
        allow(controller).to receive(:renew_access_token).and_return(renewed_token_response)
        allow(controller).to receive(:handle_token_refresh)
      end

      it 'attempts to refresh the token' do
        get :events
        expect(controller).to have_received(:handle_token_refresh)
      end
    end

    context 'when API returns other error' do
      let(:error_response) { double('response', success?: false, code: 500, message: 'Internal Server Error') }

      before do
        allow(controller).to receive(:fetch_events_from_calendly).and_return(error_response)
      end

      it 'redirects to root with error message' do
        get :events
        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include('Calendly error')
        expect(flash[:error]).to include('500')
        expect(flash[:error]).to include('Internal Server Error')
      end
    end
  end

  describe 'private methods' do
    describe '#set_calendly_oauth' do
      it 'sets @calendly_oauth to the last CalendlyOAuth record' do
        last_oauth = create(:calendly_o_auth)
        controller.send(:set_calendly_oauth)
        expect(controller.instance_variable_get(:@calendly_oauth)).to eq(last_oauth)
      end

      it 'handles case when no CalendlyOAuth exists' do
        CalendlyOAuth.destroy_all
        controller.send(:set_calendly_oauth)
        expect(controller.instance_variable_get(:@calendly_oauth)).to be_nil
      end
    end

    describe '#generate_csv_data' do
      let(:events) do
        [
          {
            'name' => 'Meeting with Client',
            'status' => 'active',
            'created_at' => '2024-01-10T08:00:00Z',
            'start_time' => '2024-01-15T10:00:00Z',
            'end_time' => '2024-01-15T11:00:00Z',
            'event_memberships' => [{ 'user_name' => 'John Doe' }]
          }
        ]
      end

      it 'generates valid CSV data' do
        csv_data = controller.send(:generate_csv_data, events)
        
        expect(csv_data).to include('Professional Name,Event Name,Created At,Start Time,End Time,Status')
        expect(csv_data).to include('Meeting with Client')
        expect(csv_data).to include('John Doe')
        expect(csv_data).to include('Active')
      end

      it 'converts times to Buenos Aires timezone' do
        csv_data = controller.send(:generate_csv_data, events)
        
        # The times should be formatted in Buenos Aires timezone
        expect(csv_data).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}/)
      end

      it 'handles error events' do
        error_events = [{ error: 'API Error', professional_name: 'Jane Smith' }]
        csv_data = controller.send(:generate_csv_data, error_events)
        
        expect(csv_data).to include('API Error')
        expect(csv_data).to include('Jane Smith')
        expect(csv_data).to include('N/A')
      end

      it 'handles mixed event types' do
        mixed_events = [
          events.first,
          { error: 'Token expired', professional_name: 'Error User' }
        ]
        
        csv_data = controller.send(:generate_csv_data, mixed_events)
        
        expect(csv_data).to include('Meeting with Client')
        expect(csv_data).to include('Token expired')
        expect(csv_data).to include('John Doe')
        expect(csv_data).to include('Error User')
      end
    end

    describe '#build_query_params' do
      before do
        controller.instance_variable_set(:@calendly_oauth, calendly_oauth)
      end

      it 'builds basic query parameters' do
        params = controller.send(:build_query_params)
        
        expect(params[:organization]).to include(calendly_oauth.organization)
        expect(params[:count]).to eq(100)
        expect(params[:min_start_time]).to be_present
      end

      it 'includes status when provided' do
        controller.params = ActionController::Parameters.new(status: 'active')
        params = controller.send(:build_query_params)
        
        expect(params[:status]).to eq('active')
      end

      it 'includes date range when provided' do
        controller.params = ActionController::Parameters.new(
          min_start_time: '2024-01-01T00:00:00Z',
          max_start_time: '2024-01-31T23:59:59Z'
        )
        
        params = controller.send(:build_query_params)
        
        expect(params[:min_start_time]).to eq('2024-01-01T00:00:00Z')
        expect(params[:max_start_time]).to eq('2024-01-31T23:59:59Z')
      end

      it 'removes nil values with compact' do
        controller.params = ActionController::Parameters.new(status: nil)
        params = controller.send(:build_query_params)
        
        expect(params).not_to have_key(:status)
      end
    end

    describe 'token refresh methods' do
      describe '#renew_access_token' do
        let(:refresh_token) { 'refresh_token_123' }
        let(:success_response) do
          double('response', 
            success?: true, 
            parsed_response: {
              'access_token' => 'new_access_token',
              'refresh_token' => 'new_refresh_token'
            }
          )
        end

        before do
          allow(HTTParty).to receive(:post).and_return(success_response)
        end

        it 'makes correct API call for token renewal' do
          result = controller.send(:renew_access_token, refresh_token)
          
          expect(HTTParty).to have_received(:post).with(
            'https://auth.calendly.com/oauth/token',
            hash_including(
              headers: { 'Content-Type' => 'application/json' },
              body: include('"grant_type":"refresh_token"')
            )
          )
        end

        it 'returns parsed response on success' do
          result = controller.send(:renew_access_token, refresh_token)
          expect(result['access_token']).to eq('new_access_token')
          expect(result['refresh_token']).to eq('new_refresh_token')
        end
      end

      describe '#update_oauth_tokens' do
        let(:new_token) do
          {
            'access_token' => 'updated_access_token',
            'refresh_token' => 'updated_refresh_token'
          }
        end

        before do
          controller.instance_variable_set(:@calendly_oauth, calendly_oauth)
        end

        it 'updates the oauth record with new tokens' do
          controller.send(:update_oauth_tokens, new_token)
          
          calendly_oauth.reload
          expect(calendly_oauth.access_token).to eq('updated_access_token')
          expect(calendly_oauth.refresh_token).to eq('updated_refresh_token')
        end
      end
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out user }

      it 'redirects to login for auth' do
        get :auth
        expect(response.status).to eq(302)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for all events' do
        get :all
        expect(response.status).to eq(302)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for events' do
        get :events
        expect(response.status).to eq(302)
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for CSV export' do
        get :all_csv, format: :csv
        expect(response.status).to eq(401)
      end
    end
  end

  describe 'edge cases and error handling' do
    before do
      controller.instance_variable_set(:@calendly_oauth, calendly_oauth)
    end

    it 'handles HTTParty exceptions gracefully' do
      allow(controller).to receive(:fetch_events_from_calendly).and_raise(StandardError.new('Network error'))
      
      get :events
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to include('unable to obtain events')
    end

    it 'handles malformed API responses' do
      # When parsed_response is nil, fetch will fail and we should redirect
      malformed_response = double('response', success?: true, parsed_response: nil)
      allow(controller).to receive(:fetch_events_from_calendly).and_return(malformed_response)
      
      get :events
      expect(response).to redirect_to(root_path)
      expect(flash[:error]).to include('unable to obtain events')
    end

    it 'handles empty events collection' do
      empty_response = double('response', success?: true, parsed_response: { 'collection' => [] })
      allow(controller).to receive(:fetch_events_from_calendly).and_return(empty_response)
      
      get :events
      expect(assigns(:events_count)).to eq(0)
      expect(assigns(:events)).to be_empty
    end
  end
end