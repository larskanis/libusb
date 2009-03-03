#!/usr/bin/ruby

require "mkmf"

pkg_config("libusb-1.0")
create_makefile("ribusb")
