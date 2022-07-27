# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "tncl" => "TNCL"
)
loader.setup

module TNCL
end
