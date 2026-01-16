ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def assert_queries_count(expected_count, &block)
      count = 0
      # 2. Subscribe to all SQL events sent by Active Record
      # 'sql.active_record' is the internal channel Rails uses for DB logging
      counter_f = ->(name, started, finished, unique_id, payload) {
        # Filter out "noise" (schema changes, transactions, etc.)
        # We only care about SELECT, INSERT, UPDATE, DELETE
        unless payload[:name].to_s.include?("SCHEMA") || payload[:name].to_s.include?("TRANSACTION")
          count += 1
        end
      }
      # 3. Listen while the block runs
      ActiveSupport::Notifications.subscribed(counter_f, "sql.active_record", &block)

      assert_equal expected_count, count, "Expected #{expected_count} queries, but #{count} were executed."
    end
  end
end
