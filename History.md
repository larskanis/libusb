0.6.0 / YYYY-MM-DD
------------------
* Update bundled libusb version to 1.0.21.
* Set minimum Ruby version requirement to 1.9.3.
* Add binary gems for Linux in addition to Windows.
* Switch to mini_portile2 for (cross-) builing the libusb library.
* Add Context#interrupt_event_handler new in libusb-1.0.21
* Add support for persistent/zerocopy device memory for transfers.
  It is new in libusb-1.0.21 and enabled by default for DevHandle#*_transfer methods.
* Raise a more meaningful exception in case of bulk stream transfers on too old libusb versions.
* Prefer the bundled libusb-dll over installed system library.

0.5.1 / 2015-09-29
------------------
* Add ability to force use of the system or builtin libusb-1.0 library.
    Use: gem install libusb -- --enable-system-libusb / --disable-system-libusb
* Update to libusb-1.0.20.
* Build Windows binary gems per rake-compiler-dock.
* Fix memory leak in Context#pollfds and use libusb_free_pollfds() if available.

0.5.0 / 2015-01-08
------------------
* Add support for BOS describtors of libusb-1.0.16
* Add support for superspeed endpoint companion descriptors of libusb-1.0.16
* Add support for USB-3.0 bulk streams of libusb-1.0.19
* Update bundled libusb version to 1.0.19.
* Update windows cross build to gcc-4.8 and recent rubygems

0.4.1 / 2014-05-17
------------------
* Update bundled libusb version to 1.0.18.
* Change libusbx references back to libusb, since they have merged again.

0.4.0 / 2013-11-20
------------------
* Add support for device hotplug notifications.
* Update to libusbx-1.0.17.
* Add DevHandle#auto_detach_kernel_driver= of libusb-1.0.16.
* Add new capabilities introduced with libusb-1.0.16.
* Offer #has_capability? for libusb versions older than 1.0.9.
* Add new method port_numbers with alias to port_path.
* Use libusb_get_port_numbers preferred to now deprecated libusb_get_port_path.

0.3.4 / 2013-04-05
------------------
* Avoid closing of pollfds by the Ruby GC when used as IO object.

0.3.3 / 2013-04-05
------------------
* Build and package binary x64 version of libusb for Windows in addition to x86.
* Fix build on Windows from source gem (although may take almost an hour).

0.3.2 / 2013-02-16
------------------
* Don't enforces DevKit installation on Windows.
* Fix error check on libusb_get_device_list(). Thanks to Paul Kunysch for the bug report.
* Add support for Cygwin. Requires ffi-1.4.0.

0.3.1 / 2013-01-22
------------------
* Fix loading of compiled libusb library on OSX

0.3.0 / 2013-01-21
------------------
* Build bundled libusbx sources in case libusb-1.0.so can not be loaded from the system
* Replace Hoe with Bundler
* Add timeout and completion_flag to Context#handle_events
* Add asynchronous DevHandle#{control|interrupt|bulk}_transfer method variants
* Add the ability to retrieve the data already transfered when it comes to an exception
* Add notification API for libusb's file describtors for event driven USB transfers
* Add experimental integration to EventMachine
* Add several convenience methods to descriptors
* Add missing return code checks to libusb_init() and libusb_get_device_list()

0.2.2 / 2012-10-19
------------------
* Add method Interface#bInterfaceNumber
* Fix methods (#claim_interface, #detach_kernel_driver) with Interface-type parameter
* update to libusbx-1.0.14 for windows build

0.2.1 / 2012-09-25
------------------
* Rename Configuration#maxPower to #bMaxPower as done in libusbx-1.0.13 and in ruby-usb.gem
* update to libusbx-1.0.13 for windows build (with support for libusbK and libusb0)

0.2.0 / 2012-06-15
------------------
* Divide up the libusb library across multiple files, required with autoload
* add methods: LIBUSB.has_capability?, Device#device_speed (libusb-1.0.9+)
* add possibility to read out libusb version: LIBUSB.version (libusbx-1.0.10+)
* add methods: Device#parent, Device#port_number, Device#port_path (libusbx-1.0.12+)
* switch to libusbx-1.0.12 for windows build

0.1.3 / 2012-03-15
-------------------
* Add documentation of descriptor accessors
* Fix #extra accessor of Configuration, Setting and Endpoint

0.1.2 / 2012-03-14
------------------
* Mark all blocking functions as blocking in FFI, so that parallel threads are not blocked
* Add method Device#open_interface
* Add block variant to #claim_interface
* update API documentation

0.1.1 / 2011-12-09
------------------
* avoid ffi calls with :blocking=>true, als long as it isn't stable on win32

0.1.0 / 2011-10-01
------------------
* add test suite based on mass storage devices
* usable async transfers
* migration to rake-compiler and hoe
* cross compiled Windows gems
* distinct exception classes
* new compatibility layer for ruby-usb.gem
* many helper methods for different USB descriptors
* add LIBUSB constants
* downcase methods names

0.0.1 / 2009-06-23
------------------
* first public release
