#!/usr/bin/ruby

require "mkmf"

dir_config("ribusb")

pkg_config("libusb-1.0")
$CFLAGS += " -Wall"

create_makefile("ribusb")
