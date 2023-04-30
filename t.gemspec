# coding: utf-8

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "t/version"

Gem::Specification.new do |spec|
  spec.add_dependency "geokit", "~> 1.9"
  spec.add_dependency "htmlentities", "~> 4.3"
  spec.add_dependency "launchy", "~> 2.4"
  spec.add_dependency "oauth", "~> 0.5.1"
  spec.add_dependency "retryable", "~> 3.0"
  spec.add_dependency "thor", [">= 0.19.1", "< 2"]
  spec.add_dependency "twitter", "~> 8.0"
  spec.author = "Erik Berlin"
  spec.description = "A command-line power tool for Twitter."
  spec.email = "sferik@gmail.com"
  spec.executables = Dir["bin/*"].map { |f| File.basename(f) }
  spec.files = %w[CONTRIBUTING.md LICENSE.md README.md t.gemspec] + Dir["bin/*"] + Dir["lib/**/*.rb"]
  spec.homepage = "http://sferik.github.com/t/"
  spec.licenses = %w[MIT]
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.name = "t"
  spec.require_paths = %w[lib]
  spec.required_ruby_version = ">= 3.0"
  spec.summary = "CLI for Twitter"
  spec.version = T::Version
end
