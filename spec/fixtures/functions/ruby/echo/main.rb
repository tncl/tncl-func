#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "fdk"

def main(payload)
  payload
end

TNCL::FDK.handle(method(:main))
