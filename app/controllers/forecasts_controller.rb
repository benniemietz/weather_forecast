class ForecastsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :get_forecast ]

  def index; end

  def get_forecast
    @forecast = WeatherApiService.new.get_forecast(params[:location])

    respond_to do |format|
      if @forecast[:error]
        format.js { render :get_forecast, status: :unprocessable_entity }
      else
        format.js
      end
    end
  end
end
