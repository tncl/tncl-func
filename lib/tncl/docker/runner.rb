# frozen_string_literal: true

class TNCL::Docker::Runner < TNCL::ProcessRunner
  attr_reader :image

  DOCKER_RUN_COMMAND = ["docker", "run", "-i", "--rm", "--pull", "never", "--name"].freeze

  def initialize(image, parent: ::Async::Task.current)
    super(*DOCKER_RUN_COMMAND, image, image, parent:)

    @image = image
  end
end
