# frozen_string_literal: true

require "zeitwerk"
loader = Zeitwerk::Loader.for_gem
loader.setup

require "async"

module Tncl
  module Func
    class Error < StandardError; end
    # Your code goes here...
  end
end
