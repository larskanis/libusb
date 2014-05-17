#!/usr/bin/env ruby

require 'rubygems'
require 'ffi'

if RUBY_PLATFORM =~ /java/
  # JRuby's C extension support is disabled by default, so we can not easily test
  # for udev availability and therefore suppose to have none.
  have_udev = false
else
  require 'mkmf'
  have_udev = true
end


begin
  module LibTest
    extend FFI::Library

    root_path = File.expand_path("../..", __FILE__)
    ext = FFI::Platform::LIBSUFFIX
    prefix = FFI::Platform::LIBPREFIX.empty? ? 'lib' : FFI::Platform::LIBPREFIX
    bundled_dll = File.join(root_path, "lib/#{prefix}usb-1.0.#{ext}")
    bundled_dll_cygwin = File.join(root_path, "bin/#{prefix}usb-1.0.#{ext}")
    ffi_lib(["#{prefix}usb-1.0", bundled_dll, bundled_dll_cygwin])
  end
rescue LoadError
  # Unable to load libusb library on this system,
  # so we build our bundled version:

  libusb_dir = Dir[File.expand_path('../../ext/libusb-*', __FILE__)].first
  root_dir = File.expand_path('../..', __FILE__)
  raise "could not find embedded libusb sources" unless libusb_dir

  # Enable udev for hot-plugging when it is available.
  # This is the same check that is done in libusb's configure.ac file
  # but we don't abort in case it's not available, but continue
  # without hot-plugging.
  have_udev &&= have_header('libudev.h') && have_library('udev', 'udev_new')

  old_dir = Dir.pwd
  Dir.chdir libusb_dir
  cmd = "sh configure #{'--disable-udev' unless have_udev} --prefix=#{root_dir} && make && make install"
  puts cmd
  system cmd
  raise "libusb build exited with #{$?.exitstatus}" if $?.exitstatus!=0
  Dir.chdir old_dir
end

File.open("Makefile", "w") do |mf|
  mf.puts "# Dummy makefile since libusb-1.0 is usable on this system"
  mf.puts "all install::\n"
end
