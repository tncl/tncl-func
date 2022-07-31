# frozen_string_literal: true

module TNCL
  module Docker
    class Runner < ProcessRunner
      attr_reader :image

      DOCKER_RUN_COMMAND = ["docker", "run", "-i", "--rm", "--pull", "never", "--name"].freeze

      def initialize(image, parent: ::Async::Task.current)
        super(*DOCKER_RUN_COMMAND, image, image, parent:)

        @image = image
      end
    end
  end
end
