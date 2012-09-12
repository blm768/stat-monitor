# -*- encoding: utf-8 -*-
require File.expand_path('../lib/statmonitor/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Ben Merritt"]
  gem.email         = ["blm768@gmail.com"]
  gem.description   = %q{A simple remote status monitor for computers on a network}
  gem.summary       = %q{A simple remote status monitor for computers on a network}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "statmonitor"
  gem.require_paths = ["lib"]
  gem.version       = StatMonitor::VERSION
  gem.extensions    = ["ext/statmonitor/extconf.rb"]

  gem.add_development_dependency('rspec')
end
