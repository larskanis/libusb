# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ribusb}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.requirements << "libusb, version 1.0 or greater"
  s.authors = ["András G. Major"]
  s.date = %q{2009-06-23}
  s.description = %q{RibUSB is a Ruby extension that makes USB devices accessible from Ruby via the libusb library (API version >=1.0).}
  s.email = %q{andras.g.major@gmail.com}
  s.files = ["ribusb.c", "README", "COPYING"]
  s.extensions << "extconf.rb"
  s.has_rdoc = true
  s.homepage = %q{http://ribusb.rubyforge.net/}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.rubyforge_project = %q{ribusb}
  s.summary = %q{Access USB devices from Ruby via libusb.}

#  if s.respond_to? :specification_version then
#    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
#    s.specification_version = 2
#
#    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
#      s.add_runtime_dependency(%q<mime-types>, [">= 1.15"])
#      s.add_runtime_dependency(%q<diff-lcs>, [">= 1.1.2"])
#    else
#      s.add_dependency(%q<mime-types>, [">= 1.15"])
#      s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
#    end
#  else
#    s.add_dependency(%q<mime-types>, [">= 1.15"])
#    s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
#  end
end
