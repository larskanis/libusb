# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "libusb/version_gem"
require_relative 'ext/libusb_recipe'

libusb_recipe = LibusbRecipe.new
libusb_recipe.download

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

  s.rubyforge_project = "libusb"

  s.files         = `git ls-files`.split("\n")
  # add libusb-1.0.x.tar.bz2 to the gem
  s.files         += libusb_recipe.files_hashs.map{|f| f[:local_path].gsub(__dir__+'/', '') }
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.extensions    = ['ext/extconf.rb']

  s.required_ruby_version = Gem::Requirement.new(">= 1.9.3")
  s.add_runtime_dependency 'ffi', '~> 1.0'
  s.add_runtime_dependency 'mini_portile2', '~> 2.1'
  s.add_development_dependency 'rake-compiler', '~> 0.9'
  s.add_development_dependency 'rake-compiler-dock', '~> 0.2'
  s.add_development_dependency 'bundler', '~> 1.8'
end
