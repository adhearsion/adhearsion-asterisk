# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "adhearsion/asterisk/version"

Gem::Specification.new do |s|
  s.name        = "adhearsion-asterisk"
  s.version     = Adhearsion::Asterisk::VERSION
  s.authors     = ["Ben Langfeld", "Taylor Carpenter"]
  s.email       = ["blangfeld@adhearsion.com", "taylor@codecafe.com"]
  s.homepage    = "http://adhearsion.com"
  s.summary     = %q{Asterisk specific features for Adhearsion}
  s.description = %q{An Adhearsion Plugin providing Asterisk-specific dialplan methods, AMI access, and access to Asterisk configuration}

  s.rubyforge_project = "adhearsion-asterisk"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # s.add_runtime_dependency %q<adhearsion>, [">= 2.0.0"]
  s.add_runtime_dependency %q<activesupport>, [">= 3.0.10"]

  s.add_development_dependency %q<bundler>, ["~> 1.0.0"]
  s.add_development_dependency %q<rspec>, [">= 2.5.0"]
  s.add_development_dependency %q<ci_reporter>, [">= 1.6.3"]
  s.add_development_dependency %q<simplecov>, [">= 0"]
  s.add_development_dependency %q<simplecov-rcov>, [">= 0"]
  s.add_development_dependency %q<yard>, ["~> 0.6.0"]
  s.add_development_dependency %q<rake>, [">= 0"]
  s.add_development_dependency %q<mocha>, [">= 0"]
  s.add_development_dependency %q<bones>
  s.add_development_dependency %q<guard-rspec>
  if RUBY_PLATFORM =~ /darwin/
    s.add_development_dependency %q<growl_notify>
    s.add_development_dependency %q<rb-fsevent>
  elsif RUBY_PLATFORM =~ /linux/
    gem 'rb-inotify', :require => false
  end
end
