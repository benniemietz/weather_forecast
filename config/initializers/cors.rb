Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "yourdomain.com", "anotherdomain.com"  # List allowed domains or use '*' for any domain (not recommended for production)

    resource "/forecasts/get_forecast",
      headers: :any,
      methods: [ :get, :post, :options ],  # Adjust methods as needed
      credentials: true  # Set to false if you don't need cookies/auth
  end
end
