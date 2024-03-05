module LIBUSB
  LIBUSB_VERSION = ENV['LIBUSB_VERSION'] || '1.0.27'
  LIBUSB_SOURCE_URI = "https://github.com/libusb/libusb/releases/download/v#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2"
  LIBUSB_SOURCE_SHA256 = 'ffaa41d741a8a3bee244ac8e54a72ea05bf2879663c098c82fc5757853441575'

  MINI_PORTILE_VERSION = '~> 2.1'
end
