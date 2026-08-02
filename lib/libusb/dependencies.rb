module LIBUSB
  LIBUSB_VERSION = ENV['LIBUSB_VERSION'] || '1.0.30'
  LIBUSB_SOURCE_URI = "https://github.com/libusb/libusb/releases/download/v#{LIBUSB_VERSION}/libusb-#{LIBUSB_VERSION}.tar.bz2"
  LIBUSB_SOURCE_SHA256 = 'fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf'

  MINI_PORTILE_VERSION = '~> 2.1'
end
