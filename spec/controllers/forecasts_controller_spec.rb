require 'rails_helper'

RSpec.describe ForecastsController, type: :controller do
  describe "GET #index" do
    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #get_forecast" do
    context "when forecasting a location" do
      let(:location) { "New York, NY" }

      before do
        # Use a fixed cassette name for test
        VCR.use_cassette("weather_forecast_for_#{location.parameterize}") do
          get :get_forecast, params: { location: location }, format: :js
        end
      end

      it "assigns a forecast and returns appropriate response" do
        expect(assigns(:forecast)).to be_present
        expect(response.content_type).to include('text/javascript')
      end

      it "includes both low and high temperatures in the forecast" do
        forecast = assigns(:forecast)

        expect(forecast['days'].first['tempmin']).to be_present
        expect(forecast['days'].first['tempmin']).to be_a Numeric
        expect(forecast['days'].first['tempmax']).to be_present
        expect(forecast['days'].first['tempmax']).to be_a Numeric
      end

      it "includes multiple days in the forecast" do
        forecast = assigns(:forecast)
        expect(forecast['days'].length).to be > 1
      end
    end

    context "when an address is invalid" do
      let(:invalid_address) { "NonExistentPlace123" }

      before do
        # Use a fixed cassette name for error cases
        VCR.use_cassette("invalid_address_forecast") do
          get :get_forecast, params: { address: invalid_address }, format: :js
        end
      end

      it "returns an error response with 422 status code" do
        expect(response.content_type).to include('text/javascript')
        expect(response).to have_http_status(:unprocessable_entity)
        expect(assigns(:forecast)[:error]).to be_present
      end
    end
  end
end
