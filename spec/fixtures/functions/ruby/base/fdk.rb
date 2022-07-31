# frozen_string_literal: true

require "base64"

require "async"

module TNCL
  module FDK
    class << self
      def handle(callable)
        $stdin.sync = true
        $stdout.sync = true
        $stderr.sync = true

        Async do
          ready!

          loop do
            write(callable.call(read))
          end
        end
      end

      def read
        $stdin.wait_readable
        Base64.decode64($stdin.read($stdin.nread).strip)
      end

      def write(payload) = puts(Base64.encode64(payload))

      def ready! = write("READY")
    end
  end
end
