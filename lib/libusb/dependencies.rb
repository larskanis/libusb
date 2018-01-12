module LIBUSB
  LIBUSB_VERSION = ENV['LIBUSB_VERSION'] || '1.0.22-rc1'
  LIBUSB_SOURCE_URI = "https://github.com/libusb/libusb/releases/download/v#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2"
  LIBUSB_SOURCE_SHA1 = '09598cd30a315203ce5bacadc38b3a720bc1c9a8'

  MINI_PORTILE_VERSION = '~> 2.1'
end
