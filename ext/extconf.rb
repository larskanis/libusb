#!/usr/bin/ruby

require "mkmf"

dir_config("libusb")

if enable_config("win32-static-build")
  have_library 'ole32', 'CLSIDFromString'
  have_library 'setupapi', 'SetupDiEnumDeviceInfo', 'setupapi.h'

  abort "libusb-1.0 not found" unless
    have_header('libusb.h') &&
    have_library( 'usb-1.0', 'libusb_open', 'libusb.h' )
else
  pkg_config("libusb-1.0")
end

$CFLAGS += " -Wall"
have_func 'rb_hash_lookup'

create_makefile("ribusb_ext")
