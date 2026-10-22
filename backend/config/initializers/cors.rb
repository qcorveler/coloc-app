# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

allowed_origins = ENV.fetch("FRONTEND_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
allowed_origins = [ "http://localhost:5173" ] if allowed_origins.empty? && Rails.env.development?

if allowed_origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*allowed_origins)

      resource "*",
        headers: :any,
        methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
        credentials: true
    end
  end
end
