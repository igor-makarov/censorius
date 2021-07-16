# frozen_string_literal: true

require 'censorius'
require 'xcodeproj'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# extension for more descriptive testing
class Array
  def sorted_md5s
    map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end
end

module Xcodeproj
  # extension for more descriptive testing
  class Project
    def sorted_md5s
      objects_by_uuid.keys.sort
    end
  end
end
