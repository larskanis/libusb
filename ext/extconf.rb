#!/usr/bin/env ruby

require 'rubygems'
require 'ffi'
require 'fileutils'

include FileUtils

if RUBY_PLATFORM =~ /java/
  # JRuby's C extension support is disabled by default, so we can not easily test
  # for udev availability and therefore suppose to have none.
  have_udev = false

  # Implement very simple verions of mkmf-helpers used below
  def enable_config(name, default=nil)
    if ARGV.include?("--enable-#{name}")
      true
    elsif ARGV.include?("--disable-#{name}")
      false
    else
      default
    end
  end

  def arg_config(name)
    ARGV.include?(name)
  end
else
  require 'mkmf'
  have_udev = true
end

def do_help
  print <<HELP
usage: ruby #{$0} [options]

    --enable-system-libusb / --disable-system-libusb
      Force use of system or builtin libusb library.
      Default is to prefer system libraries and fallback to builtin.
HELP
  exit! 0
end

do_help if arg_config('--help')

def libusb_usable?
  begin
    Module.new do
      extend FFI::Library

      root_path = File.expand_path("../..", __FILE__)
      ext = FFI::Platform::LIBSUFFIX
      prefix = FFI::Platform::LIBPREFIX.empty? ? 'lib' : FFI::Platform::LIBPREFIX
      bundled_dll = File.join(root_path, "lib/#{prefix}usb-1.0.#{ext}")
      bundled_dll_cygwin = File.join(root_path, "bin/#{prefix}usb-1.0.#{ext}")
      ffi_lib([bundled_dll, bundled_dll_cygwin, "#{prefix}usb-1.0"])
    end
    true
  rescue LoadError
    false
  end
end

def build_bundled_libusb(have_udev)
  # Enable udev for hot-plugging when it is available.
  # This is the same check that is done in libusb's configure.ac file
  # but we don't abort in case it's not available, but continue
  # without hot-plugging.
  have_udev &&= have_header('libudev.h') && have_library('udev', 'udev_new')

  require_relative '../lib/libusb/libusb_recipe'
  recipe = LIBUSB::LibusbRecipe.new
  recipe.configure_options << "--disable-udev" unless have_udev
  recipe.cook_and_activate
  recipe.path
end

unless enable_config('system-libusb', libusb_usable?)
  # Unable to load libusb library on this system,
  # so we build our bundled version:
  libusb_path = build_bundled_libusb(have_udev)
end

# Create a Makefile which copies the libusb library files to the gem's lib dir.
File.open("Makefile", "wb") do |mf|
  mf.puts <<-EOT
RUBYARCHDIR = #{RbConfig::MAKEFILE_CONFIG['sitearchdir'].dump}
all:
clean:
install:
EOT

  if libusb_path
    mf.puts <<-EOT
	cp -r #{libusb_path.dump}/*/* $(RUBYARCHDIR)
    EOT
  end
end
