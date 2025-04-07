# README

## Application Description

This is a Ruby-based weather application that provides forecast data using the Visual Crossing Weather API. The app allows users to retrieve weather information for specific locations and view forecasts.

* Ruby version: 3.x.x 

## Installation

To install the required dependencies, run:

```bash
bundle install
```

This will install all gems specified in the Gemfile.

## Running the Application

To start the Rails server, run:

```bash
rails server
# or the shorthand version
rails s
```

By default, the server will run on port 3000. You can access the application by visiting `http://localhost:3000` in your web browser.

To run the server on a different port:

```bash
rails server -p 4000
```

* Configuration
## Weather API Configuration

This application uses the [Visual Crossing Weather API](https://www.visualcrossing.com/weather-api/) to retrieve weather forecast data. To use this feature, you'll need to set up the following environment variables:

### Required Environment Variables

- `WEATHER_API_KEY`: Your Visual Crossing API key
- `WEATHER_URL`: The base URL for the Visual Crossing API (typically `https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline`)

### Getting an API Key

1. Visit [Visual Crossing Weather API](https://www.visualcrossing.com/weather-api)
2. Sign up for an account
3. Once registered, you can access your API key from your account dashboard

### Setting Up Environment Variables

For development, you can use a `.env` file in your application root:

* How to run the test suite

### Running Tests with RSpec

This project uses RSpec for testing. To run the test suite:

```bash
bundle exec rspec --format documentation
```

* ...

