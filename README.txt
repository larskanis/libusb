= Access USB devices from Ruby via libusb.

* http://ribusb.rubyforge.net/

== DESCRIPTION:

RibUSB is a Ruby extension that gives a Ruby programmer access to all functionality of libusb, version 1.0.

* libusb is a library that gives full access to devices connected via the USB bus. No kernel driver is thus necessary for accessing USB devices. Linux support is ready, ports to other systems are bound to appear with time.
* This Ruby extension supports the API version 1.0 of libusb. Note that the old "legacy" version 0.1.x of libusb uses a completely different API and is thus not supported.
* The API is currently work-in-progress. Do not rely on it being stable just yet.

This project is being developed by András G. Major and is hosted on RubyForge. The RubyForge project page is located here.

RibUSB is covered by the GNU Public License version 2.

== SYNOPSIS:

  require "ribusb"

  usb = RibUSB::Bus.new
  device = usb.find(:idVendor => 0x04b4, :idProduct => 0x8613).first
  device.configuration = 1
  device.claimInterface(0)
  device.controlTransfer(:bmRequestType => 0x40, :bRequest => 0xa0, :wValue => 0xe600, :wIndex => 0x0000, :dataOut => 1.chr)
  device.releaseInterface(0)

== REQUIREMENTS:

* libusb version 1.0 or greater

== INSTALL:

In order to install RibUSB from source code, you need a working Ruby installation, including its
header files and build utilities (on Debian and Ubuntu systems, part the ruby-dev package). Also,
you need a C compiler (usually gcc), and make. The libusb-1.0 library along with its header files
must naturally be present (on Debian and Ubuntu system, install the libusb-1.0-0-dev package).

To install from gem, execute this command to download RibUSB and to build it:

  gem install ribusb

To install from source, execute this command to configure RibUSB and to build it:

  git clone ...
  rake install_gem

From now on, you can use the RibUSB extension from any instance of Ruby on that computer by
"requiring" it from within your Ruby program:

  require "ribusb"

Please browse the documentation on the website for example uses of RibUSB. Have fun.
