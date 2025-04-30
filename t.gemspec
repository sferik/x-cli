# coding: utf-8

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "t/version"

Gem::Specification.new do |spec|
  spec.add_dependency "geokit", "~> 1.14"
  spec.add_dependency "htmlentities", "~> 4.3"
  spec.add_dependency "launchy", "~> 3.0"
  spec.add_dependency "oauth", "~> 1.1"
  spec.add_dependency "retryable", "~> 3.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "twitter", "~> 8.2"
  spec.author = "Erik Berlin"
  spec.description = "A command-line power tool for Twitter."
  spec.email = "sferik@gmail.com"
  spec.executables = Dir["bin/*"].map { |f| File.basename(f) }
  spec.files = %w[CONTRIBUTING.md LICENSE.md README.md t.gemspec] + Dir["bin/*"] + Dir["lib/**/*.rb"]
  spec.homepage = "http://sferik.github.com/t/"
  spec.licenses = %w[MIT]

  spec.metadata = {
    "allowed_push_host" => "https://rubygems.org",
    "bug_tracker_uri" => "https://github.com/sferik/t-ruby/issues",
    "changelog_uri" => "https://github.com/sferik/t-ruby/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://rubydoc.info/gems/t/",
    "funding_uri" => "https://github.com/sponsors/sferik/",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/sferik/t-ruby",
  }

  spec.name = "t"
  spec.require_paths = %w[lib]
  spec.required_ruby_version = ">= 3.2"
  spec.summary = "CLI for Twitter"
  spec.version = T::Version
end
