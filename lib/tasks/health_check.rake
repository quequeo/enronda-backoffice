namespace :health do
  desc "Health check endpoint for monitoring"
  task check: :environment do
    health_status = {
      status: 'healthy',
      timestamp: Time.current.iso8601,
      checks: {}
    }
    
    begin
      # Database check
      User.connection.execute("SELECT 1")
      health_status[:checks][:database] = 'healthy'
    rescue => e
      health_status[:checks][:database] = "unhealthy: #{e.message}"
      health_status[:status] = 'unhealthy'
    end
    
    begin
      # Redis check (if configured)
      if ENV['REDIS_URL']
        Rails.cache.write('health_check', 'ok', expires_in: 1.minute)
        Rails.cache.read('health_check')
        health_status[:checks][:redis] = 'healthy'
      else
        health_status[:checks][:redis] = 'not_configured'
      end
    rescue => e
      health_status[:checks][:redis] = "unhealthy: #{e.message}"
      health_status[:status] = 'unhealthy'
    end
    
    # Environment variables check
    required_vars = %w[CALENDLY_CLIENT_ID CALENDLY_CLIENT_SECRET CALENDLY_REDIRECT_URI]
    missing_vars = required_vars.select { |var| ENV[var].blank? }
    
    if missing_vars.empty?
      health_status[:checks][:environment] = 'healthy'
    else
      health_status[:checks][:environment] = "unhealthy: missing #{missing_vars.join(', ')}"
      health_status[:status] = 'unhealthy'
    end
    
    puts health_status.to_json
    
    # Exit with error code if unhealthy
    exit 1 if health_status[:status] == 'unhealthy'
  end
end