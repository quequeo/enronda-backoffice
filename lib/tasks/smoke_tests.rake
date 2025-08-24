namespace :smoke_tests do
  desc "Run smoke tests to verify deployment"
  task all: :environment do
    puts "🔥 Running smoke tests..."
    
    begin
      # Test 1: Database connectivity
      puts "✅ Testing database connection..."
      User.connection.execute("SELECT 1")
      puts "   Database: OK"
      
      # Test 2: Redis connectivity (if configured)
      if ENV['REDIS_URL']
        puts "✅ Testing Redis connection..."
        Rails.cache.write('smoke_test', 'ok', expires_in: 1.minute)
        result = Rails.cache.read('smoke_test')
        raise "Redis test failed" unless result == 'ok'
        puts "   Redis: OK"
      end
      
      # Test 3: Environment variables
      puts "✅ Testing required environment variables..."
      required_vars = %w[CALENDLY_CLIENT_ID CALENDLY_CLIENT_SECRET CALENDLY_REDIRECT_URI]
      required_vars.each do |var|
        raise "Missing #{var}" if ENV[var].blank?
      end
      puts "   Environment variables: OK"
      
      # Test 4: Models and validations
      puts "✅ Testing model validations..."
      user = User.new(email: 'test@invalid.com', password: 'password123')
      raise "User validation not working" if user.valid?
      puts "   Model validations: OK"
      
      # Test 5: CalendlyService instantiation
      puts "✅ Testing CalendlyService..."
      auth_url = CalendlyService.authorize_url
      raise "CalendlyService not working" unless auth_url.include?('calendly.com')
      puts "   CalendlyService: OK"
      
      # Test 6: Asset compilation
      puts "✅ Testing asset availability..."
      if Rails.env.production?
        manifest_path = Rails.root.join('public', 'assets', '.sprockets-manifest*.json')
        raise "Assets not compiled" if Dir.glob(manifest_path).empty?
      end
      puts "   Assets: OK"
      
      puts "\n🎉 All smoke tests passed!"
      
    rescue => e
      puts "\n❌ Smoke test failed: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end
  
  desc "Test Calendly API connectivity with real credentials"
  task calendly_api: :environment do
    puts "🔗 Testing Calendly API connectivity..."
    
    # Solo correr si hay un professional con token en la DB
    professional = Professional.where.not(token: nil).first
    
    if professional.nil?
      puts "⚠️  No professionals with tokens found. Skipping API test."
      return
    end
    
    begin
      # Test real API call
      response = HTTParty.get(
        'https://api.calendly.com/users/me',
        headers: {
          'Authorization' => "Bearer #{professional.token}",
          'Content-Type' => 'application/json'
        },
        timeout: 10
      )
      
      if response.success?
        puts "✅ Calendly API: OK (Status: #{response.code})"
        puts "   Organization: #{response.parsed_response.dig('resource', 'current_organization')}"
      else
        puts "❌ Calendly API failed: #{response.code} - #{response.message}"
      end
      
    rescue => e
      puts "❌ Calendly API error: #{e.message}"
    end
  end
  
  desc "Test critical user flows"
  task user_flows: :environment do
    puts "👤 Testing critical user flows..."
    
    begin
      # Test 1: User authentication flow
      puts "✅ Testing user creation..."
      test_user = User.create!(
        email: 'hola@enronda.com', 
        password: 'testpassword123',
        password_confirmation: 'testpassword123'
      )
      puts "   User creation: OK"
      
      # Test 2: Professional creation
      puts "✅ Testing professional creation..."
      test_professional = Professional.create!(
        name: 'Test Professional',
        token: 'test_token_123',
        email: 'test@professional.com'
      )
      puts "   Professional creation: OK"
      
      # Test 3: Service integration
      puts "✅ Testing service integration..."
      # Mock para evitar llamada real a API
      allow(CalendlyService).to receive(:professional_events).and_return([])
      events = CalendlyService.professional_events(test_professional, {})
      puts "   Service integration: OK"
      
      # Cleanup
      test_user.destroy
      test_professional.destroy
      puts "   Cleanup: OK"
      
      puts "🎉 User flows test passed!"
      
    rescue => e
      puts "❌ User flows test failed: #{e.message}"
      # Cleanup on error
      test_user&.destroy
      test_professional&.destroy
    end
  end
end