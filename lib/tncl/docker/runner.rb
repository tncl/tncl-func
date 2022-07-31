# frozen_string_literal: true

class TNCL::Docker::Runner < TNCL::ProcessRunner
  class Error < StandardError; end

  class InitializationError < Error; end

  class InitializationTimeoutError < InitializationError; end
  class NotReadyError < InitializationError; end
  class ImageNotFoundError < InitializationError; end
  class WrongReadyMessageError < InitializationError; end

  DOCKER_RUN_COMMAND = ["docker", "run", "-i", "--rm", "--pull", "never", "--name"].freeze

  attr_reader :image

  def initialize(image, parent: ::Async::Task.current)
    super(*DOCKER_RUN_COMMAND, image, image, parent:)

    @image = image
  end
end
