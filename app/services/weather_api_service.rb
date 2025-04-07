class WeatherApiService

  def initialize
    @api_key = ENV['WEATHER_API_KEY']
    @weather_url = ENV['WEATHER_URL']
  end

  # Get the forecast for a given location using this API https://www.visualcrossing.com/weather-api/
  def get_forecast(location)
    # Generate a cache key based on the location
    cache_key = generate_cache_key(location)

    # Fetch the forecast from the cache or make an API call if not cached, delete the cache if the API call fails
    Rails.cache.fetch(cache_key, expires_in: 30.minutes) do
      encoded_location = ERB::Util.url_encode(location)
      api_url = "#{ENV['WEATHER_URL']}/#{encoded_location}/next7days?unitGroup=us&key=#{ENV['WEATHER_API_KEY']}&include=days&contentType=json"
      
      response = HTTParty.get(api_url, format: :plain)
      
      if response.success?
        begin
          JSON.parse(response.body)
        rescue JSON::ParserError => e
          Rails.cache.delete(cache_key)
          { error: true, message: "Invalid JSON response: #{response.body}", status: response.code }
        end
      else
        Rails.cache.delete(cache_key)
        { error: true, message: response.message || response.body, status: response.code }
      end
    end
  end
  
  private
  
  # Extract zip code from location string
  def extract_zip_code(location)
    # Match US zip code pattern (5 digits, optionally followed by dash and 4 more digits)
    zip_match = location.to_s.match(/\b(\d{5}(?:-\d{4})?)\b/)
    zip_match[1] if zip_match
  end

  def generate_cache_key(location)
    # Extract zip code from location if possible
    zip_code = extract_zip_code(location) 
    
    zip_code ? "weather_forecast_#{zip_code}" : "weather_forecast_#{location.to_s.parameterize(separator: "_")}"
  end
end
