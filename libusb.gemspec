# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "libusb/version_gem"

Gem::Specification.new do |s|
  s.name        = "libusb"
  s.version     = LIBUSB::VERSION
  s.authors     = ["Lars Kanis"]
  s.email       = ["lars@greiz-reinsdorf.de"]
  s.homepage    = "http://github.com/larskanis/libusb"
  s.summary     = %q{Access USB devices from Ruby via libusb-1.0}
  s.description = %q{LIBUSB is a Ruby binding that gives Ruby programmers access to arbitrary USB devices}
  s.rdoc_options = %w[--main README.md --charset=UTF-8]

  s.rubyforge_project = "libusb"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.extensions    = ['ext/extconf.rb']

  # travis currently runs a slightly older version of rbx,
  # that needs a special ffi version.
  unless ENV['TRAVIS'] && defined?(RUBY_ENGINE) && RUBY_ENGINE=='rbx'
    s.add_runtime_dependency 'ffi', '>= 1.0'
  end

  s.add_development_dependency 'rake-compiler', '>= 0.6'
  s.add_development_dependency 'bundler'
end
