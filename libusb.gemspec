# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "libusb/version_gem"
require "libusb/dependencies"

Gem::Specification.new do |s|
  s.name        = "libusb"
  s.version     = LIBUSB::VERSION
  s.authors     = ["Lars Kanis"]
  s.email       = ["lars@greiz-reinsdorf.de"]
  s.homepage    = "http://github.com/larskanis/libusb"
  s.summary     = %q{Access USB devices from Ruby via libusb-1.0}
  s.description = %q{LIBUSB is a Ruby binding that gives Ruby programmers access to arbitrary USB devices}
  s.licenses    = ['LGPL-3.0']
  s.rdoc_options = %w[--main README.md --charset=UTF-8]

  s.files         = `git ls-files`.split("\n")
  s.files         << "ports/archives/libusb-#{LIBUSB::LIBUSB_VERSION}.tar.bz2"
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.extensions    = ['ext/extconf.rb']
  s.metadata["yard.run"] = "yri"

  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0")
  s.add_runtime_dependency 'ffi', '~> 1.0'
  s.add_runtime_dependency 'mini_portile2', LIBUSB::MINI_PORTILE_VERSION
end
