
require 'libusb'

RibUSB = LIBUSB

module RibUSB
  Call::ClassCode.to_h.each{|k,v| const_set("LIBUSB_#{k}",v) }
  Call::TransferTypes.to_h.each{|k,v| const_set("LIBUSB_#{k}",v) }
  Call::EndpointDirections.to_h.each{|k,v| const_set("LIBUSB_#{k}",v) }

  class Configuration < FFI::Struct
    alias interface_descriptors settings
  end

  class Interface < FFI::Struct
    alias alt_settings settings
  end
  class Endpoint < FFI::Struct
    alias interface_descriptor setting
  end
  class Context
  end

  class Device
    alias interface_descriptors settings
  end

  class Handle
  end

end
