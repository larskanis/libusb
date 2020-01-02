source "http://rubygems.org"

# Specify your gem's dependencies in libusb.gemspec
gemspec

group :test do
  gem 'eventmachine'
  gem 'minitest'
end

gem 'rake-compiler-dock', '~> 1.0'

# For some reason this is required in addition to the gemspec
# when 'bundle config force_ruby_platform true' is active:
gem 'ffi'
gem 'mini_portile2'
