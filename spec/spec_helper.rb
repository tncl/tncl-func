# frozen_string_literal: true

require "English"
require "fileutils"

require "async/rspec"
require "dead_end"

require "tncl/func"

Zeitwerk::Loader.eager_load_all

# pp Dir["#{__dir__}}/support/**/*.rb"]
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| load(f) }

shared_files = Dir["#{File.dirname(__FILE__)}/fixtures/functions/ruby/base/*"]

Dir["#{File.dirname(__FILE__)}/fixtures/functions/ruby/*"].each do |fn|
  name = File.basename(fn)
  next if name == "base" # skip shared for all functions stuff

  shared_files.each do |f|
    FileUtils.copy(f, fn)
  end

  Dir.chdir(fn) do
    `docker build . -t #{name}`
    next if $CHILD_STATUS.success?

    raise "Cannot build function '#{name}'"
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include_context(Async::RSpec::Reactor)
end
