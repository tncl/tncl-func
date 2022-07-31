#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "fdk"

module TNCL
  module FDK
    class << self
      def ready!
        Async::Task.current.sleep(10)
        write("BLAH BLAH")
      end
    end
  end
end

def main(payload)
  payload
end

TNCL::FDK.handle(method(:main))
