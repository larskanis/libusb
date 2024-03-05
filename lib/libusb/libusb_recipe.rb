require_relative 'dependencies'
require 'rubygems'
# Keep the version constraint in sync with libusb.gemspec
gem "mini_portile2", LIBUSB::MINI_PORTILE_VERSION
require "mini_portile2"

module LIBUSB
  class LibusbRecipe < MiniPortile
    ROOT = File.expand_path('../../..', __FILE__)

    def initialize
      super("libusb", LIBUSB_VERSION)
      self.target = File.join(ROOT, "ports")
      self.files = [url: LIBUSB_SOURCE_URI, sha256: LIBUSB_SOURCE_SHA256]
      self.patch_files = Dir[File.join(ROOT, "patches", self.name, self.version, "*.patch")].sort
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
end
