#!/usr/bin/env ruby
# frozen_string_literal: true

require "base64"

require "async"

require_relative "fdk"

def main(payload)
  payload
end

MCL::FDK.handle(method(:main))
