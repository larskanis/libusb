source "http://rubygems.org"

# Specify your gem's dependencies in libusb.gemspec
# gemspec

group :test do
  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('4.0')
    # Ruby 4.0 removed Data_Wrap_Struct, breaking eventmachine 1.2.7's
    # fastfilereader ext; use git master until a fix is released.
    gem 'eventmachine', github: 'eventmachine/eventmachine'
  else
    gem 'eventmachine'
  end
  gem 'minitest'
end

gem 'rake-compiler-dock', '~> 1.1'
gem 'rake-compiler', '~> 1.0'
gem 'bundler', '>= 1', '< 5.a'
gem 'yard', '~> 0.6', '>= 0.9.36'
gem 'ostruct', '~> 0.1'

# For some reason this is required in addition to the gemspec
# when 'bundle config force_ruby_platform true' is active:
gem 'ffi'
gem 'mini_portile2'
