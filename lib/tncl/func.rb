# frozen_string_literal: true

require "forwardable"

require "async"
require "async/io"
require "async/process"
require "async/notification"

require "tncl"

module TNCL
  module Func
    class Error < StandardError; end
  end
end
