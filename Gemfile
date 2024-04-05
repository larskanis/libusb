source "http://rubygems.org"

# Specify your gem's dependencies in libusb.gemspec
gemspec

group :eventmachine do
  gem 'eventmachine'
end
group :test do
  gem 'minitest'
end

gem 'rake-compiler-dock', '~> 1.5-rc1'
gem 'rake-compiler', '~> 1.0'
gem 'bundler', '>= 1', '< 3'
gem 'yard', '~> 0.6', '>= 0.9.36'

# For some reason this is required in addition to the gemspec
# when 'bundle config force_ruby_platform true' is active:
gem 'ffi', '~> 1.17.0.rc1'
gem 'mini_portile2'
