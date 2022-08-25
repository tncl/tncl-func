# frozen_string_literal: true

RSpec.shared_examples "returns nil" do
  it "returns nil" do
    expect(subject).to be_nil
  end
end

RSpec.shared_examples "returns true" do
  it "returns true" do
    expect(subject).to be(true)
  end
end

RSpec.shared_examples "returns false" do
  it "returns false" do
    expect(subject).to be(false)
  end
end
