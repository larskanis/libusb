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
