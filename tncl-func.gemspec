# frozen_string_literal: true

require_relative "lib/tncl/func/version"

Gem::Specification.new do |spec|
  spec.name = "tncl-func"
  spec.version = Tncl::Func::VERSION
  spec.authors = ["Gleb Sinyavskiy"]
  spec.email = ["zhulik.gleb@gmail.com"]

  spec.summary = "Simple self hosted FaaS for personal use."
  spec.description = "Simple self hosted FaaS for personal use."
  spec.homepage = "https://github.com/tncl/tncl-func"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "zeitwerk", "~> 2.6.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata["rubygems_mfa_required"] = "true"
end
