require 'rails_helper'

RSpec.describe Professional, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:token) }

    describe 'name validation' do
      it 'is valid with a name' do
        professional = build(:professional, name: 'John Doe')
        expect(professional).to be_valid
      end

      it 'is invalid without a name' do
        professional = build(:professional, name: nil)
        expect(professional).not_to be_valid
        expect(professional.errors[:name]).to include("can't be blank")
      end

      it 'is invalid with empty name' do
        professional = build(:professional, name: '')
        expect(professional).not_to be_valid
        expect(professional.errors[:name]).to include("can't be blank")
      end
    end

    describe 'token validation' do
      it 'is valid with a token' do
        professional = build(:professional, token: 'valid_token_123')
        expect(professional).to be_valid
      end

      it 'is invalid without a token' do
        professional = build(:professional, token: nil)
        expect(professional).not_to be_valid
        expect(professional.errors[:token]).to include("can't be blank")
      end

      it 'is invalid with empty token' do
        professional = build(:professional, token: '')
        expect(professional).not_to be_valid
        expect(professional.errors[:token]).to include("can't be blank")
      end
    end
  end

  describe 'attributes' do
    let(:professional) { create(:professional) }

    it 'has a name' do
      expect(professional.name).to be_present
      expect(professional.name).to be_a(String)
    end

    it 'has a token' do
      expect(professional.token).to be_present
      expect(professional.token).to be_a(String)
    end

    it 'can have an email' do
      professional.email = 'test@example.com'
      expect(professional.email).to eq('test@example.com')
    end

    it 'can have a phone' do
      professional.phone = '+1234567890'
      expect(professional.phone).to eq('+1234567890')
    end

    it 'can have an organization' do
      org_url = 'https://api.calendly.com/organizations/12345'
      professional.organization = org_url
      expect(professional.organization).to eq(org_url)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      professional = build(:professional)
      expect(professional).to be_valid
    end

    it 'creates a professional with valid attributes' do
      professional = create(:professional)
      expect(professional.name).to be_present
      expect(professional.token).to be_present
      expect(professional).to be_persisted
    end
  end

  describe 'factory traits' do
    describe ':without_token' do
      it 'creates an invalid professional without token' do
        professional = build(:professional, :without_token)
        expect(professional).not_to be_valid
        expect(professional.token).to be_nil
      end
    end

    describe ':without_organization' do
      it 'creates a professional without organization' do
        professional = build(:professional, :without_organization)
        expect(professional.organization).to be_nil
        expect(professional).to be_valid # Still valid as organization is optional
      end
    end

    describe ':invalid' do
      it 'creates an invalid professional' do
        professional = build(:professional, :invalid)
        expect(professional).not_to be_valid
        expect(professional.name).to be_nil
        expect(professional.token).to be_nil
      end
    end
  end

  describe 'database columns' do
    it { should have_db_column(:name).of_type(:string) }
    it { should have_db_column(:token).of_type(:string) }
    it { should have_db_column(:phone).of_type(:string) }
    it { should have_db_column(:email).of_type(:string) }
    it { should have_db_column(:organization).of_type(:string) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'edge cases' do
    it 'handles very long names' do
      long_name = 'A' * 1000
      professional = build(:professional, name: long_name)
      expect(professional).to be_valid
    end

    it 'handles special characters in name' do
      special_name = 'José María Ñoño-González'
      professional = build(:professional, name: special_name)
      expect(professional).to be_valid
    end

    it 'handles very long tokens' do
      long_token = 'token_' + 'a' * 500
      professional = build(:professional, token: long_token)
      expect(professional).to be_valid
    end
  end
end