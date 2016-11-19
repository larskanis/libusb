require 'rubygems'
# NOTE: Keep this version constraint in sync with libusb.gemspec
gem "mini_portile2", "~> 2.1"
require "mini_portile2"

class LibusbRecipe < MiniPortile
  VERSION = ENV['LIBUSB_VERSION'] || '1.0.21'
  SOURCE_URI = "https://github.com/libusb/libusb/releases/download/v#{VERSION}/libusb-#{VERSION}.tar.bz2"
  SOURCE_SHA1 = '54d71841542eb1a6f0b0420878a4d5434efe8d28'

  ROOT = File.expand_path('../..', __FILE__)

  def initialize
    super("libusb", VERSION)
    self.target = File.join(ROOT, "ports")
    self.files = [url: SOURCE_URI, sha1: SOURCE_SHA1]
    self.configure_options = []
  end

  def cook_and_activate
    checkpoint = File.join(self.target, "#{self.name}-#{self.version}-#{self.host}.installed")
    unless File.exist?(checkpoint)
      self.cook
      FileUtils.touch checkpoint
    end
    self.activate
    self
  end

  public :files_hashs
end
