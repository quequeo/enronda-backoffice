require 'rails_helper'

RSpec.describe CalendlyOAuth, type: :model do
  describe 'attributes' do
    let(:oauth) { create(:calendly_o_auth) }

    it 'has an access_token' do
      expect(oauth.access_token).to be_present
      expect(oauth.access_token).to be_a(String)
    end

    it 'has a refresh_token' do
      expect(oauth.refresh_token).to be_present
      expect(oauth.refresh_token).to be_a(String)
    end

    it 'has an owner' do
      expect(oauth.owner).to be_present
      expect(oauth.owner).to be_a(String)
    end

    it 'has an organization' do
      expect(oauth.organization).to be_present
      expect(oauth.organization).to be_a(String)
    end

    it 'has timestamps' do
      expect(oauth.created_at).to be_present
      expect(oauth.updated_at).to be_present
    end
  end

  describe 'database columns' do
    it { should have_db_column(:access_token).of_type(:string) }
    it { should have_db_column(:refresh_token).of_type(:string) }
    it { should have_db_column(:owner).of_type(:string) }
    it { should have_db_column(:organization).of_type(:string) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      oauth = build(:calendly_o_auth)
      expect(oauth).to be_valid
    end

    it 'creates an oauth record with valid attributes' do
      oauth = create(:calendly_o_auth)
      expect(oauth.access_token).to be_present
      expect(oauth.refresh_token).to be_present
      expect(oauth.owner).to be_present
      expect(oauth.organization).to be_present
      expect(oauth).to be_persisted
    end
  end

  describe 'factory traits' do
    describe ':expired' do
      it 'creates an oauth with expired token' do
        oauth = create(:calendly_o_auth, :expired)
        expect(oauth.access_token).to include('expired_token_')
      end
    end

    describe ':without_refresh_token' do
      it 'creates an oauth without refresh token' do
        oauth = create(:calendly_o_auth, :without_refresh_token)
        expect(oauth.refresh_token).to be_nil
        expect(oauth.access_token).to be_present
      end
    end
  end

  describe 'find_or_create_by behavior' do
    let(:owner_id) { SecureRandom.uuid }
    let(:org_url) { "https://api.calendly.com/organizations/#{SecureRandom.uuid}" }

    it 'creates a new record when none exists' do
      expect {
        CalendlyOAuth.find_or_create_by(owner: owner_id, organization: org_url)
      }.to change(CalendlyOAuth, :count).by(1)
    end

    it 'finds existing record when one exists' do
      existing = create(:calendly_o_auth, owner: owner_id, organization: org_url)
      
      found = CalendlyOAuth.find_or_create_by(owner: owner_id, organization: org_url)
      
      expect(found.id).to eq(existing.id)
      expect(CalendlyOAuth.count).to eq(1)
    end

    it 'updates existing record tokens' do
      existing = create(:calendly_o_auth, owner: owner_id, organization: org_url)
      new_access_token = 'new_access_token_123'
      new_refresh_token = 'new_refresh_token_123'
      
      existing.update(access_token: new_access_token, refresh_token: new_refresh_token)
      
      expect(existing.reload.access_token).to eq(new_access_token)
      expect(existing.reload.refresh_token).to eq(new_refresh_token)
    end
  end

  describe 'token management' do
    let(:oauth) { create(:calendly_o_auth) }

    it 'can update access token' do
      new_token = 'updated_access_token_456'
      oauth.update(access_token: new_token)
      
      expect(oauth.reload.access_token).to eq(new_token)
    end

    it 'can update refresh token' do
      new_refresh = 'updated_refresh_token_456'
      oauth.update(refresh_token: new_refresh)
      
      expect(oauth.reload.refresh_token).to eq(new_refresh)
    end

    it 'can update both tokens simultaneously' do
      new_access = 'new_access_789'
      new_refresh = 'new_refresh_789'
      
      oauth.update(access_token: new_access, refresh_token: new_refresh)
      oauth.reload
      
      expect(oauth.access_token).to eq(new_access)
      expect(oauth.refresh_token).to eq(new_refresh)
    end
  end

  describe 'organization and owner relationship' do
    it 'can have multiple oauth records for different owners' do
      org_url = "https://api.calendly.com/organizations/#{SecureRandom.uuid}"
      owner1 = SecureRandom.uuid
      owner2 = SecureRandom.uuid
      
      oauth1 = create(:calendly_o_auth, owner: owner1, organization: org_url)
      oauth2 = create(:calendly_o_auth, owner: owner2, organization: org_url)
      
      expect(oauth1.organization).to eq(oauth2.organization)
      expect(oauth1.owner).not_to eq(oauth2.owner)
      expect(CalendlyOAuth.count).to eq(2)
    end

    it 'can have multiple oauth records for different organizations' do
      owner_id = SecureRandom.uuid
      org1 = "https://api.calendly.com/organizations/#{SecureRandom.uuid}"
      org2 = "https://api.calendly.com/organizations/#{SecureRandom.uuid}"
      
      oauth1 = create(:calendly_o_auth, owner: owner_id, organization: org1)
      oauth2 = create(:calendly_o_auth, owner: owner_id, organization: org2)
      
      expect(oauth1.owner).to eq(oauth2.owner)
      expect(oauth1.organization).not_to eq(oauth2.organization)
      expect(CalendlyOAuth.count).to eq(2)
    end
  end

  describe 'edge cases' do
    it 'handles nil values gracefully' do
      oauth = CalendlyOAuth.new
      expect(oauth.access_token).to be_nil
      expect(oauth.refresh_token).to be_nil
      expect(oauth.owner).to be_nil
      expect(oauth.organization).to be_nil
    end

    it 'handles empty string values' do
      oauth = CalendlyOAuth.new(
        access_token: '',
        refresh_token: '',
        owner: '',
        organization: ''
      )
      
      expect(oauth.access_token).to eq('')
      expect(oauth.refresh_token).to eq('')
      expect(oauth.owner).to eq('')
      expect(oauth.organization).to eq('')
    end

    it 'handles very long token values' do
      long_token = 'token_' + 'a' * 1000
      oauth = create(:calendly_o_auth, access_token: long_token)
      
      expect(oauth.access_token).to eq(long_token)
    end
  end
end