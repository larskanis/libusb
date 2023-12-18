module LIBUSB
  LIBUSB_VERSION = ENV['LIBUSB_VERSION'] || '1.0.27-rc1'
  LIBUSB_SOURCE_URI = "https://github.com/libusb/libusb/releases/download/v#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2"
  LIBUSB_SOURCE_SHA1 = '634d547205b8ffb92828ce5ced431ade23cd719e'

  MINI_PORTILE_VERSION = '~> 2.1'
end
