source "http://rubygems.org"

# Specify your gem's dependencies in libusb.gemspec
gemspec

group :test do
  gem 'eventmachine'
  gem 'minitest'
end

platforms :rbx do
  # travis currently runs a slightly older version of rbx,
  # that needs this special ffi version.
  if ENV['TRAVIS']
    gem 'ffi', :git => "git://github.com/ffi/ffi.git", :ref => '5f31908'
  end
end
