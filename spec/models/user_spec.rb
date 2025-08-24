require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }

    describe 'restricted_email validation' do
      context 'with authorized email' do
        it 'is valid with hola@enronda.com' do
          user = build(:user, email: 'hola@enronda.com')
          expect(user).to be_valid
        end
      end

      context 'with unauthorized email' do
        it 'is invalid with any other email' do
          user = build(:user, email: 'test@example.com')
          expect(user).not_to be_valid
          expect(user.errors[:email]).to include('is not authorized for this app. Please contact support')
        end

        it 'normalizes email case due to Devise behavior' do
          # Note: Devise automatically downcases emails before validation
          user = build(:user, email: 'HOLA@ENRONDA.COM')
          expect(user).to be_valid # Devise converts it to lowercase
          expect(user.email).to eq('hola@enronda.com')
        end
      end
    end
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end

    it 'includes rememberable' do
      expect(User.devise_modules).to include(:rememberable)
    end

    it 'includes validatable' do
      expect(User.devise_modules).to include(:validatable)
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      user = build(:user)
      expect(user).to be_valid
    end

    it 'creates a user with valid attributes' do
      user = create(:user)
      expect(user.email).to eq('hola@enronda.com')
      expect(user).to be_persisted
    end
  end

  describe 'password validation' do
    it 'requires a password' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'requires password confirmation to match' do
      user = build(:user, password: 'password123', password_confirmation: 'different')
      expect(user).not_to be_valid
      expect(user.errors[:password_confirmation]).to be_present
    end

    it 'requires minimum password length' do
      user = build(:user, password: '12345', password_confirmation: '12345')
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end
  end
end