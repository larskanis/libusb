Access USB devices from Ruby
============================

LIBUSB is a Ruby binding that gives Ruby programmers access to arbitrary USB devices.

* [libusbx](http://libusbx.org) is a library that gives full access to devices connected via the USB
  bus. No special kernel driver is thus necessary for accessing USB devices.

* This Ruby binding supports the API version 1.0 of [libusbx](http://libusbx.org). Note that the old
  "legacy" version 0.1.x of libusb uses a completely different API that is covered by the ruby
  extension [ruby-usb](http://www.a-k-r.org/ruby-usb/).

Get the code and contribute:

* [Fork the repository](http://github.com/larskanis/libusb).

* [Open an issue](https://github.com/larskanis/libusb/issues).

Features
--------

* Access to descriptors of devices, configurations, interfaces, settings and endpoints.

* Synchronous and asynchronous communication for bulk, control, interrupt and isochronous
  transfers.

* Compatibility layer for [ruby-usb](http://www.a-k-r.org/ruby-usb/) (API based on libusb-0.1). See
  {::USB} for description.

Synopsis
--------

``` ruby
  require 'libusb'

  usb = LIBUSB::Context.new
  device = usb.devices(:idVendor => 0x04b4, :idProduct => 0x8613).first
  device.open_interface(0) do |handle|
    handle.control_transfer(:bmRequestType => 0x40, :bRequest => 0xa0, :wValue => 0xe600, :wIndex => 0x0000, :dataOut => 1.chr)
  end
```

`LIBUSB::Context#devices` is used to get all or only particular devices.

After `LIBUSB::Device#open_interface` opening and claiming the `LIBUSB::Device` the resulting
`LIBUSB::DevHandle` can be used to communicate with the connected USB device by
using `LIBUSB::DevHandle#control_transfer`, `LIBUSB::DevHandle#bulk_transfer`,
`LIBUSB::DevHandle#interrupt_transfer` or by using the `LIBUSB::Transfer` classes.

A `LIBUSB::Device` can also be used to retrieve information about it,
by using the device descriptor attributes.
A `LIBUSB::Device` could have several configurations. You can then decide of which
configuration to enable. You can only enable one configuration at a time.

Each `LIBUSB::Configuration` has one or more interfaces. These can be seen as functional group
performing a single feature of the device.

Each `LIBUSB::Interface` has at least one `LIBUSB::Setting`. The first setting is always default.
An alternate setting can be used independent on each interface.

Each `LIBUSB::Setting` specifies it's own set of communication endpoints.
Each `LIBUSB::Endpoint` specifies the type of transfer, direction, polling interval and
maximum packet size.

Prerequisites
-------------

* GNU/Linux, MacOSX or Windows system with Ruby MRI 1.8.7/1.9.x or JRuby.

* [libusbx](http://libusbx.org/)

Installation
------------

Add this line to your application's Gemfile:

    gem 'libusb'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install libusb

Or live on the edge with:

    $ git clone git://github.com/larskanis/libusb.git
    $ rake install_gem

Inside of your Ruby program do:

    require 'libusb'

...to pull it in as a dependency.

Special notes on Windows usage
------------------------------

In contrast to Linux, any access to an USB device by LIBUSB on Windows requires a proper driver
installed in the system. Fortunately creating such a driver is quite easy with
[Zadig](http://sourceforge.net/projects/libwdi/files/zadig/). Select the interesting USB device,
choose WinUSB driver and press "Install Driver". That's it. You may take the generated output
directory with it's INI-file and use it for driver installation on other 32 or 64 bit Windows
systems.

The libusb gem can be build on a linux or darwin host for the win32 platform,
using the mingw cross compiler collection. libusb is downloaded from source
git repo, cross compiled and included in the generated libusb.gem.

Install mingw32. On a debian based system this should work:

    $ apt-get install mingw32

On MacOS X, if you have MacPorts installed:

    $ port install i386-mingw32-gcc

Download and cross compile libusb for win32:

    $ rake cross gem

If everything works fine, there should be libusb-VERSION-x86-mingw32.gem in the pkg
directory.

Resources
---------

* API documentation of Libusb for Ruby: http://rubydoc.info/gems/libusb/frames

* Mailinglist: http://rubyforge.org/mailman/listinfo/libusb-hackers

* Overall introduction to USB: http://www.usbmadesimple.co.uk

TODO
----

* Add proper handling for [polling and timing](http://libusbx.sourceforge.net/api-1.0/group__poll.html).

* Add proper handling for [Asynchronous Device I/O](http://libusbx.sourceforge.net/api-1.0/group__asyncio.html).

* Rubinius support.

Copyright
---------

```
 The libusb gem is free software: you can redistribute it and/or modify
 it under the terms of the GNU Lesser General Public License as published
 by the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 The libusb gem is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public License
 along with the libusb gem.  If not, see <http://www.gnu.org/licenses/>.
 ```
