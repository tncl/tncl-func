# frozen_string_literal: true

require "English"
require "fileutils"

require "async/rspec"
require "dead_end"

require "simplecov"

SimpleCov.start do
  add_filter "spec"
end

require "tncl/func"

Zeitwerk::Loader.eager_load_all

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| load(f) }
ENV["CONSOLE_LEVEL"] ||= "warn"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include_context(Async::RSpec::Reactor)

  config.before(:suite) do
    shared_files = Dir["#{File.dirname(__FILE__)}/fixtures/functions/ruby/base/*"]

    Dir["#{File.dirname(__FILE__)}/fixtures/functions/ruby/*"].each do |fn|
      name = File.basename(fn)
      next if name == "base" # skip shared for all functions stuff

      shared_files.each do |f|
        FileUtils.copy(f, fn)
      end

      Dir.chdir(fn) do
        puts("Building test function #{name}...")
        `docker build . -t #{name}`
        next if $CHILD_STATUS.success?

        raise "Cannot build function '#{name}'"
      end
    end
  end
end
