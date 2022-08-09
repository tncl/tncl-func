#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "fdk"

def main(payload)
  Async::Task.current.sleep(11)
  payload
end

TNCL::FDK.handle(method(:main))
