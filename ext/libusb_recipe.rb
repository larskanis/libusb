require_relative '../lib/libusb/dependencies'
require 'rubygems'
# NOTE: Keep this version constraint in sync with libusb.gemspec
gem "mini_portile2", LIBUSB::MINI_PORTILE_VERSION
require "mini_portile2"

class LibusbRecipe < MiniPortile
  include LIBUSB
  ROOT = File.expand_path('../..', __FILE__)

  def initialize
    super("libusb", LIBUSB_VERSION)
    self.target = File.join(ROOT, "ports")
    self.files = [url: LIBUSB_SOURCE_URI, sha1: LIBUSB_SOURCE_SHA1]
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
