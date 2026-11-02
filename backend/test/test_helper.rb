ENV["RAILS_ENV"] ||= "test"
ENV["VAPID_PUBLIC_KEY"] ||= "test-public-key"
ENV["VAPID_PRIVATE_KEY"] ||= "test-private-key"
ENV["VAPID_SUBJECT"] ||= "https://coloc.test"
require_relative "../config/environment"
require "rails/test_help"

BCrypt::Engine.cost = BCrypt::Engine::MIN_COST

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
