# frozen_string_literal: true

RSpec.describe TNCL::Func::Function do
  let(:function) { described_class.new(name: "echo", image:) }
  let(:image) { "echo" } # TODO: add function to fixtures so it can be built before tests

  after do
    function.stop
  end

  describe "#start" do
    subject { function.start }

    context "when image exists" do # rubocop:disable Lint/EmptyBlock, RSpec/EmptyExampleGroup
    end

    context "when image does not exist" do
      let(:image) { "image-does-not-exist" }

      include_examples "raises an exception", described_class::ImageNotFoundError,
                       "function 'echo' initialization failed: image 'image-does-not-exist' is not found"
    end
  end
end
