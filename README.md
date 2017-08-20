<!-- -*- coding: utf-8 -*- -->

[![Build Status](https://travis-ci.org/larskanis/libusb.svg?branch=master)](https://travis-ci.org/larskanis/libusb)
[![Build status](https://ci.appveyor.com/api/projects/status/mdfnfdwu4mil42o3/branch/master?svg=true)](https://ci.appveyor.com/project/larskanis/libusb/branch/master)

Access USB devices from Ruby
============================

LIBUSB is a Ruby binding that gives Ruby programmers access to arbitrary USB devices.

* [libusb](http://libusb.info) is a library that gives full access to devices connected via the USB bus. No special kernel driver is thus necessary for accessing USB devices.
* This Ruby binding supports the API version 1.0 of [libusb](http://libusb.info). Note that the old "legacy" version 0.1.x of libusb uses a completely different API that is covered by the ruby extension [ruby-usb](http://www.a-k-r.org/ruby-usb/) .


LIBUSB for Ruby is covered by the GNU Lesser General Public License version 3.

Features
--------

* Access to descriptors of devices, configurations, interfaces, settings and endpoints
* Synchronous and asynchronous communication for bulk, control, interrupt and isochronous transfers
* Support for USB-3.0 descriptors and bulk streams
* Compatibility layer for [ruby-usb](http://www.a-k-r.org/ruby-usb/) (API based on libusb-0.1). See {::USB} for description.

Synopsis
--------
```ruby
require "libusb"

usb = LIBUSB::Context.new
device = usb.devices(idVendor: 0x04b4, idProduct: 0x8613).first
device.open_interface(0) do |handle|
  handle.control_transfer(bmRequestType: 0x40, bRequest: 0xa0, wValue: 0xe600, wIndex: 0x0000, dataOut: 1.chr)
end
```
{LIBUSB::Context#devices} is used to get all or only particular devices.
After {LIBUSB::Device#open_interface opening and claiming} the {LIBUSB::Device} the resulting {LIBUSB::DevHandle} can be
used to communicate with the connected USB device
by {LIBUSB::DevHandle#control_transfer}, {LIBUSB::DevHandle#bulk_transfer},
{LIBUSB::DevHandle#interrupt_transfer} or by using the {LIBUSB::Transfer} classes.

A {LIBUSB::Device} can also be used to retrieve information about it,
by using the device descriptor attributes.
A {LIBUSB::Device} could have several configurations. You can then decide of which
configuration to enable. You can only enable one configuration at a time.

Each {LIBUSB::Configuration} has one or more interfaces. These can be seen as functional group
performing a single feature of the device.

Each {LIBUSB::Interface} has at least one {LIBUSB::Setting}. The first setting is always default.
An alternate setting can be used independent on each interface.

Each {LIBUSB::Setting} specifies it's own set of communication endpoints.
Each {LIBUSB::Endpoint} specifies the type of transfer, direction, polling interval and
maximum packet size.

See [the documentation](http://rubydoc.info/gems/libusb/frames) for a full API description.

Prerequisites
-------------

* Linux, MacOS or Windows system with Ruby MRI 1.9/2.x, JRuby or recent version of Rubinius
* Optionally: [libusb](http://libusb.info) C-library version 1.0.8 or any newer version.
  The system libusb library can be installed like so:
  * Debian or Ubuntu:

      ```
      $ sudo apt-get install libusb-1.0-0-dev
      ```
  * MacOS: install with homebrew:

      ```
      $ brew install libusb
      ```
    or macports:

      ```
      $ port install libusb
      ```
  * Windows: libusb.gem already comes with a precompiled `libusb.dll`, but you need to install a device driver (see [below](#usage-on-windows))

Install
-------

    $ gem install libusb

While ```gem install``` the system is checked for a usable libusb library installation.
If none could be found, a bundled libusb version is built and used, instead.

Latest code can be used in this way:

    $ git clone git://github.com/larskanis/libusb.git
    $ bundle
    $ rake install_gem

Troubleshooting
------------------------
In order to implement a driver for a USB device, it's essential to have a look at the packets that are send to and received back from the USB device. [Wireshark](https://www.wireshark.org) has builtin capabilities to sniff USB traffic. On Linux you possibly need to load the usbmon kernel module before start:
```
    sudo modprobe usbmon
```
On Windows it's possible to sniff USB, if the USB kernel driver was installed by the Wireshark setup.

![Wireshark](wireshark-usb-sniffer.png?raw=true "Wireshark sniffing USB packets")

Device hotplug support
----------------------

Support for device hotplugging can be used, if ```LIBUSB.has_capability?(:CAP_HAS_HOTPLUG)``` returns ```true```.
This requires libusb-1.0.16 or newer on Linux or MacOS. Windows support is [still on the way](https://github.com/libusbx/libusbx/issues/9).

A hotplug event handler can be registered with {LIBUSB::Context#on_hotplug_event}.
You then need to call {LIBUSB::Context#handle_events} in order to receive any events.
This can be done as blocking calls (possibly in it's own thread) or by using {LIBUSB::Context#pollfds} to
detect any events to handle.


Usage on Windows
----------------

In contrast to Linux, any access to an USB device by LIBUSB on Windows requires a proper driver
installed in the system. Fortunately creating such a driver is quite easy with
[Zadig](http://zadig.akeo.ie/). Select the interesting USB device,
choose WinUSB driver and press "Install Driver". That's it. You may take the generated output directory
with it's INI-file and use it for driver installations on other 32 or 64 bit Windows
systems.


Cross compiling for Windows
---------------------------

Libusb-gem can be cross built for Windows and Linux operating systems, using the [rake-compiler-dock](https://github.com/larskanis/rake-compiler-dock) .
Just run:

    $ rake gem:native

If everything works, there are several platform specific gem files (like `libusb-VERSION-x64-mingw32.gem`) in the pkg
directory.

EventMachine integration
------------------------

Libusb for Ruby comes with an experimental integration to [EventMachine](http://rubyeventmachine.com/).
That API is currently proof of concept - see {LIBUSB::Context#eventmachine_register}.
If you're experienced with EventMachine, please leave a comment.


Resources
---------

* Project's home page: http://github.com/larskanis/libusb
* API documentation: http://rubydoc.info/gems/libusb/frames
* Mailinglist: http://rubyforge.org/mailman/listinfo/libusb-hackers
* Overall introduction to USB: http://www.usbmadesimple.co.uk

Todo
----

* stabilize EventMachine interface
