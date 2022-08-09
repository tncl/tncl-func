# frozen_string_literal: true

class TNCL::Docker::Builder < TNCL::ProcessRunner
  class Error < StandardError; end

  DOCKER_BUILD_COMMAND = ["docker", "build", ".", "-t"].freeze

  attr_reader :path, :name

  def initialize(path, name, parent: ::Async::Task.current)
    @path = path
    @name = name

    super(*DOCKER_BUILD_COMMAND, name, parent:)
  end

  def spawn
    Dir.chdir(@path) do
      super
    end
  end
end
