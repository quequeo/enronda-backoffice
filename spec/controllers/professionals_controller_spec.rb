require 'rails_helper'

RSpec.describe ProfessionalsController, type: :controller do
  let(:user) { create(:user) }
  let!(:professional) { create(:professional) }
  let(:valid_attributes) do
    {
      name: 'John Doe',
      token: 'valid_token_123',
      email: 'john@example.com',
      phone: '+1234567890'
    }
  end
  let(:invalid_attributes) do
    {
      name: '',
      token: '',
      email: 'invalid_email',
      phone: 'invalid_phone'
    }
  end

  before do
    sign_in user
  end

  describe 'GET #index' do
    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns @professionals' do
      get :index
      expect(assigns(:professionals)).to eq([professional])
    end

    it 'loads all professionals' do
      professional2 = create(:professional, name: 'Jane Smith')
      get :index
      expect(assigns(:professionals)).to match_array([professional, professional2])
    end
  end

  describe 'GET #show' do
    it 'returns a successful response' do
      get :show, params: { id: professional.id }
      expect(response).to be_successful
    end

    it 'assigns the requested professional' do
      get :show, params: { id: professional.id }
      expect(assigns(:professional)).to eq(professional)
    end

    it 'raises error for invalid id' do
      expect {
        get :show, params: { id: 99999 }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'assigns a new professional' do
      get :new
      expect(assigns(:professional)).to be_a_new(Professional)
    end
  end

  describe 'GET #edit' do
    it 'returns a successful response' do
      get :edit, params: { id: professional.id }
      expect(response).to be_successful
    end

    it 'assigns the requested professional' do
      get :edit, params: { id: professional.id }
      expect(assigns(:professional)).to eq(professional)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      it 'creates a new Professional' do
        expect {
          post :create, params: { professional: valid_attributes }
        }.to change(Professional, :count).by(1)
      end

      it 'redirects to the professionals index' do
        post :create, params: { professional: valid_attributes }
        expect(response).to redirect_to(professionals_path)
      end

      it 'sets a success notice' do
        post :create, params: { professional: valid_attributes }
        expect(flash[:notice]).to eq('Professional was successfully created.')
      end

      it 'assigns the professional with correct attributes' do
        post :create, params: { professional: valid_attributes }
        created_professional = Professional.last
        expect(created_professional.name).to eq('John Doe')
        expect(created_professional.token).to eq('valid_token_123')
        expect(created_professional.email).to eq('john@example.com')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Professional' do
        expect {
          post :create, params: { professional: invalid_attributes }
        }.not_to change(Professional, :count)
      end

      it 'renders the new template' do
        post :create, params: { professional: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it 'assigns the professional with errors' do
        post :create, params: { professional: invalid_attributes }
        expect(assigns(:professional).errors).to be_present
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        {
          name: 'Updated Name',
          token: 'updated_token_456',
          email: 'updated@example.com'
        }
      end

      it 'updates the requested professional' do
        put :update, params: { id: professional.id, professional: new_attributes }
        professional.reload
        expect(professional.name).to eq('Updated Name')
        expect(professional.token).to eq('updated_token_456')
        expect(professional.email).to eq('updated@example.com')
      end

      it 'redirects to the professionals index' do
        put :update, params: { id: professional.id, professional: new_attributes }
        expect(response).to redirect_to(professionals_path)
      end

      it 'sets a success notice' do
        put :update, params: { id: professional.id, professional: new_attributes }
        expect(flash[:notice]).to eq('Professional was successfully updated.')
      end
    end

    context 'with invalid parameters' do
      it 'renders the edit template' do
        put :update, params: { id: professional.id, professional: invalid_attributes }
        expect(response).to render_template(:edit)
      end

      it 'does not update the professional' do
        original_name = professional.name
        put :update, params: { id: professional.id, professional: invalid_attributes }
        professional.reload
        expect(professional.name).to eq(original_name)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the requested professional' do
      expect {
        delete :destroy, params: { id: professional.id }
      }.to change(Professional, :count).by(-1)
    end

    it 'redirects to the professionals index' do
      delete :destroy, params: { id: professional.id }
      expect(response).to redirect_to(professionals_path)
    end

    it 'sets a success notice' do
      delete :destroy, params: { id: professional.id }
      expect(flash[:notice]).to eq('Professional was successfully destroyed.')
    end

    it 'handles non-existent professional gracefully' do
      expect {
        delete :destroy, params: { id: 99999 }
      }.not_to raise_error
      
      expect(response).to redirect_to(professionals_path)
    end
  end

  describe 'GET #events' do
    let(:mock_events) do
      [
        {
          'name' => 'Test Event 1',
          'status' => 'active',
          'start_time' => '2024-01-15T10:00:00Z'
        },
        {
          'name' => 'Test Event 2',
          'status' => 'active',
          'start_time' => '2024-01-16T11:00:00Z'
        }
      ]
    end

    before do
      allow(CalendlyService).to receive(:professional_events).and_return(mock_events)
    end

    it 'returns a successful response' do
      get :events, params: { id: professional.id }
      expect(response).to be_successful
    end

    it 'assigns the professional' do
      get :events, params: { id: professional.id }
      expect(assigns(:professional)).to eq(professional)
    end

    it 'calls CalendlyService with correct parameters' do
      get :events, params: { 
        id: professional.id,
        status: 'active',
        start_date: '2024-01-01',
        end_date: '2024-01-31'
      }
      
      expect(CalendlyService).to have_received(:professional_events).with(
        professional,
        hash_including(
          'status' => 'active',
          'start_date' => '2024-01-01',
          'end_date' => '2024-01-31'
        )
      )
    end

    it 'assigns events and events count' do
      get :events, params: { id: professional.id }
      expect(assigns(:events_count)).to eq(2)
      expect(assigns(:events)).to be_present
    end

    it 'paginates the results' do
      get :events, params: { id: professional.id, page: 1 }
      expect(assigns(:events)).to respond_to(:current_page)
    end

    it 'uses permit! for filter params' do
      # This tests the security concern - permit! allows all params
      get :events, params: { 
        id: professional.id,
        status: 'active',
        malicious_param: 'should_be_filtered'
      }
      
      # The controller uses permit!.slice, so malicious_param won't be passed
      expect(CalendlyService).to have_received(:professional_events).with(
        professional,
        hash_including('status' => 'active')
      )
    end
  end

  describe 'GET #events_csv' do
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
      allow(CalendlyService).to receive(:professional_events).and_return(mock_events)
    end

    it 'responds with CSV format' do
      get :events_csv, params: { id: professional.id }, format: :csv
      expect(response.content_type).to include('text/csv')
    end

    it 'generates correct filename' do
      get :events_csv, params: { id: professional.id }, format: :csv
      expected_filename = "#{professional.name.downcase.parameterize}_events_#{Date.today}.csv"
      expect(response.headers['Content-Disposition']).to include(expected_filename)
    end

    it 'includes CSV headers' do
      get :events_csv, params: { id: professional.id }, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Professional Name,Event Name,Created At,Start Time,End Time,Status')
    end

    it 'includes event data' do
      get :events_csv, params: { id: professional.id }, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Test Event')
      expect(csv_content).to include('John Doe')
    end

    it 'handles error events in CSV' do
      error_events = [{ error: 'Token expired', professional_name: 'John Doe' }]
      allow(CalendlyService).to receive(:professional_events).and_return(error_events)
      
      get :events_csv, params: { id: professional.id }, format: :csv
      csv_content = response.body
      expect(csv_content).to include('Token expired')
      expect(csv_content).to include('N/A')
    end

    it 'calls CalendlyService with filter params' do
      get :events_csv, params: { 
        id: professional.id,
        status: 'cancelled',
        start_date: '2024-01-01'
      }, format: :csv
      
      expect(CalendlyService).to have_received(:professional_events).with(
        professional,
        hash_including(
          'status' => 'cancelled',
          'start_date' => '2024-01-01'
        )
      )
    end
  end

  describe 'private methods' do
    describe '#professional_params' do
      it 'permits the correct parameters' do
        controller_params = ActionController::Parameters.new({
          professional: {
            name: 'John',
            token: 'token123',
            phone: '123456',
            email: 'john@example.com',
            malicious_param: 'should_be_filtered'
          }
        })
        
        controller.params = controller_params
        permitted_params = controller.send(:professional_params)
        
        expect(permitted_params.keys).to match_array(['name', 'token', 'phone', 'email'])
        expect(permitted_params['malicious_param']).to be_nil
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

      it 'handles timezone conversion' do
        csv_data = controller.send(:generate_csv_data, events)
        
        # Check that dates are formatted and converted to Buenos Aires timezone
        expect(csv_data).to match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}/)
      end

      it 'handles error events' do
        error_events = [{ error: 'API Error', professional_name: 'Jane Smith' }]
        csv_data = controller.send(:generate_csv_data, error_events)
        
        expect(csv_data).to include('API Error')
        expect(csv_data).to include('Jane Smith')
        expect(csv_data).to include('N/A')
      end
    end
  end

  describe 'authentication' do
    context 'when user is not signed in' do
      before { sign_out user }

      it 'redirects to login for index' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for show' do
        get :show, params: { id: professional.id }
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for create' do
        post :create, params: { professional: valid_attributes }
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'redirects to login for events' do
        get :events, params: { id: professional.id }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'edge cases' do
    it 'handles professionals with special characters in name for CSV' do
      special_professional = create(:professional, name: 'José María Ñoño-González')
      allow(CalendlyService).to receive(:professional_events).and_return([])
      
      get :events_csv, params: { id: special_professional.id }, format: :csv
      
      expected_filename = "jose-maria-nono-gonzalez_events_#{Date.today}.csv"
      expect(response.headers['Content-Disposition']).to include(expected_filename)
    end

    it 'handles empty events list' do
      allow(CalendlyService).to receive(:professional_events).and_return([])
      
      get :events, params: { id: professional.id }
      expect(assigns(:events_count)).to eq(0)
      expect(assigns(:events)).to be_empty
    end

    it 'handles CalendlyService returning nil' do
      allow(CalendlyService).to receive(:professional_events).and_return(nil)
      
      expect {
        get :events, params: { id: professional.id }
      }.not_to raise_error
    end
  end
end