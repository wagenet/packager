# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'packager/version'

Gem::Specification.new do |s|
  s.name        = "packager"
  s.version     = Packager::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Yehuda Katz", "Peter Wagenet"]
  s.email       = ["wycats@gmail.com", "peter.wagenet@gmail.com"]
  s.summary     = %q{Packager your gem for Mac OS X}
  s.description = %q{A tool for creating a standalone Mac OS X .pkg of your gem.}

  s.required_rubygems_version = ">= 1.3.6"

  s.add_dependency "bundler", "~> 1.1.pre.4"

  s.files              = `git ls-files`.split("\n")
  s.require_paths      = ["lib"]
end


