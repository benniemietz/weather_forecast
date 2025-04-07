require 'rails_helper'
require 'webmock/rspec'

RSpec.describe WeatherApiService do
  let(:api_key) { ENV['WEATHER_API_KEY'] }
  let(:weather_url) { ENV['WEATHER_URL'] }
  let(:location) { 'New York, NY' }
  let(:encoded_location) { 'New%20York%2C%20NY' }
  let(:service) { WeatherApiService.new }
  let(:zip_location) { "New York, NY 10001" }
  let(:mock_response) { { "days" => [ { "temp" => 72 } ] } }
  let(:error_response) { double(success?: false, code: 500, message: "Server Error", body: "") }

  before do
    # Clear the cache before each test
    Rails.cache.clear
  end

  describe '#get_forecast' do
    let(:api_url) { "#{weather_url}/#{encoded_location}/next7days?unitGroup=us&key=#{api_key}&include=days&contentType=json" }

    context 'when the API call is successful' do
      it 'returns the parsed forecast data' do
        VCR.use_cassette('weather_api/successful_forecast') do
          response = service.get_forecast(location)

          expect(response).to be_a(Hash)
          expect(response).to have_key('days')
          expect(response['days'].first).to include(
            'datetime', 'tempmax', 'tempmin', 'conditions'
          )
          expect(response).to have_key('currentConditions')
          expect(response['currentConditions']).to include(
            'temp', 'humidity', 'conditions', 'windspeed'
          )
        end
      end
    end

    context 'when the API call fails' do
      it 'returns the error response' do
        VCR.use_cassette('weather_api/failed_forecast', record: :new_episodes) do
          response = service.get_forecast('invalid-location-to-force-error')

          expect(response).to be_a(Hash)
          expect(response).to have_key(:error)
          expect(response).to have_key(:message)
          expect(response).to have_key(:status)
          expect(response[:status]).to eq(400)
        end
      end
    end

    context "caching behavior" do
      it "caches results for 30 minutes" do
        # Configure test cache to work properly
        allow(Rails.cache).to receive(:fetch).and_call_original

        # Mock the API call to return success
        stub_request = stub_request(:get, /#{ENV['WEATHER_URL']}/)
          .to_return(status: 200, body: mock_response.to_json, headers: { 'Content-Type' => 'application/json' })

        # First call should hit the API
        result1 = service.get_forecast(location)
        expect(stub_request).to have_been_requested.once

        # Second call should use cache
        result2 = service.get_forecast(location)
        expect(stub_request).to have_been_requested.once # Still just one request
        expect(result2).to eq(result1)
      end

      it "uses different cache keys for different locations" do
        # Mock the API calls
        stub_request1 = stub_request(:get, /#{ENV['WEATHER_URL']}\/.*San%20Francisco/)
          .to_return(status: 200, body: { "days" => [ { "temp" => 72 } ] }.to_json)

        stub_request2 = stub_request(:get, /#{ENV['WEATHER_URL']}\/.*New%20York/)
          .to_return(status: 200, body: { "days" => [ { "temp" => 65 } ] }.to_json)

        # Different locations should make different API calls
        service.get_forecast("San Francisco, CA")
        service.get_forecast("New York, NY")

        expect(stub_request1).to have_been_requested.once
        expect(stub_request2).to have_been_requested.once
      end

      it "uses zip code for cache key when available" do
        allow(service).to receive(:extract_zip_code).with(zip_location).and_return("10001")

        # Mock the API call
        stub_request = stub_request(:get, /#{ENV['WEATHER_URL']}/)
          .to_return(status: 200, body: mock_response.to_json)

        # Should create cache with the zip code key
        expect(Rails.cache).to receive(:fetch).with("weather_forecast_10001", expires_in: 30.minutes)

        service.get_forecast(zip_location)
      end

      it "expires cache after 30 minutes" do
        # Mock the API call
        stub_request = stub_request(:get, /#{ENV['WEATHER_URL']}/)
          .to_return(status: 200, body: mock_response.to_json)

        # First call
        service.get_forecast(location)
        expect(stub_request).to have_been_requested.once

        # Travel 31 minutes in the future
        travel_to(31.minutes.from_now) do
          # Should make a new API call after cache expiration
          service.get_forecast(location)
          expect(stub_request).to have_been_requested.twice
        end
      end

      it "deletes cache when API returns 500 error" do
        # Mock an error response
        allow(HTTParty).to receive(:get).and_return(error_response)

        # Expect Rails.cache.delete to be called with the correct cache key format
        cache_key = service.send(:generate_cache_key, location)
        expect(Rails.cache).to receive(:delete).with(cache_key)

        service.get_forecast(location)
      end
    end
  end

  describe '#extract_zip_code' do
    let(:service) { WeatherApiService.new }

    it 'extracts a 5-digit zip code from a location string' do
      location = "New York, 10001"
      expect(service.send(:extract_zip_code, location)).to eq('10001')
    end

    it 'extracts a 9-digit zip code from a location string' do
      location = "123 Main St, Philadelphia, PA 19103-1234"
      expect(service.send(:extract_zip_code, location)).to eq('19103-1234')
    end

    it 'extracts a zip code when it appears at the beginning of the string' do
      location = "90210 Beverly Hills"
      expect(service.send(:extract_zip_code, location)).to eq('90210')
    end

    it 'returns the first zip code when multiple zip codes are present' do
      location = "From 10001 to 90210"
      expect(service.send(:extract_zip_code, location)).to eq('10001')
    end

    it 'returns nil when no zip code is present' do
      location = "San Francisco, California"
      expect(service.send(:extract_zip_code, location)).to be_nil
    end

    it 'returns nil when location is nil' do
      expect(service.send(:extract_zip_code, nil)).to be_nil
    end

    it 'returns nil when location is an empty string' do
      expect(service.send(:extract_zip_code, "")).to be_nil
    end

    it 'ignores numbers that are not zip codes' do
      location = "There are 12345 people in 546 houses"
      expect(service.send(:extract_zip_code, location)).to eq('12345')
    end
  end

  describe '#generate_cache_key' do
    context 'with zip code in location' do
      it 'extracts zip code for US 5-digit format' do
        location = "New York, NY 10001"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_10001")
      end

      it 'extracts zip code for US 9-digit format' do
        location = "New York, NY 10001-1234"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_10001-1234")
      end

      it 'extracts zip code when only zip code is provided' do
        location = "10001"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_10001")
      end

      it 'handles zip code at the beginning of string' do
        location = "10001 New York, NY"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_10001")
      end
    end

    context 'without zip code in location' do
      it 'parameterizes city name' do
        location = "San Francisco, CA"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_san_francisco_ca")
      end

      it 'handles special characters in location' do
        location = "St. John's, NL, Canada"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_st_john_s_nl_canada")
      end

      it 'handles accented characters' do
        location = "Québec, Canada"
        expect(service.send(:generate_cache_key, location)).to eq("weather_forecast_quebec_canada")
      end
    end

    context 'with edge cases' do
      it 'handles nil location' do
        expect(service.send(:generate_cache_key, nil)).to eq("weather_forecast_")
      end

      it 'handles empty string location' do
        expect(service.send(:generate_cache_key, "")).to eq("weather_forecast_")
      end
    end
  end
end
