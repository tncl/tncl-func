# frozen_string_literal: true

RSpec.describe TNCL::Func::Function do
  let(:function) { described_class.new(name:, image:) }
  let(:name) { image }

  after do
    function.stop
    function.wait
  end
  # rubocop:disable RSpec/EmptyExampleGroup,RSpec/NestedGroups

  describe "#start" do
    subject { function.start }

    context "when image exists" do
      context "when container works properly" do
        let(:image) { "echo" }
      end

      context "when container prints wrong READY message" do
        let(:image) { "ready_error" }

        include_examples "raises an exception", described_class::WrongReadyMessageError,
                         "function 'ready_error': wrong ready message. Expected: 'READY', received: 'BLAH BLAH'"
      end

      context "when container does not print READY in time" do
        let(:image) { "ready_timeout" }

        include_examples "raises an exception", described_class::InitializationTimeoutError,
                         "function 'ready_timeout': initialization timed out"
      end

      context "when container initialization fails" do
        let(:image) { "initializaiton_fail" }
      end
    end

    context "when image does not exist" do
      let(:image) { "image-does-not-exist" }

      include_examples "raises an exception", described_class::ImageNotFoundError,
                       "function 'image-does-not-exist': image 'image-does-not-exist' is not found"
    end
  end
  # rubocop:enable RSpec/EmptyExampleGroup,RSpec/NestedGroups
end
