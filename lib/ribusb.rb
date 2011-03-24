#!/usr/bin/env ruby
#
# Several parts of this code are copied from ruby-usb (libusb-0.1 binding).
#

# Extend the search path for Windows binary gem, depending of the current ruby version
major_minor = RUBY_VERSION[ /^(\d+\.\d+)/ ] or
  raise "Oops, can't extract the major/minor version from #{RUBY_VERSION.dump}"
$: << File.join(File.dirname(__FILE__), major_minor)

require 'rubygems'
require 'ribusb_ext'

module RibUSB

  # :stopdoc:
  # http://www.usb.org/developers/defined_class
  CLASS_CODES = [
    [0x01, nil, nil, "Audio"],
    [0x02, nil, nil, "Comm"],
    [0x03, nil, nil, "HID"],
    [0x05, nil, nil, "Physical"],
    [0x06, 0x01, 0x01, "StillImaging"],
    [0x06, nil, nil, "Image"],
    [0x07, nil, nil, "Printer"],
    [0x08, 0x01, nil, "MassStorage RBC Bluk-Only"],
    [0x08, 0x02, 0x50, "MassStorage ATAPI Bluk-Only"],
    [0x08, 0x03, 0x50, "MassStorage QIC-157 Bluk-Only"],
    [0x08, 0x04, nil, "MassStorage UFI"],
    [0x08, 0x05, 0x50, "MassStorage SFF-8070i Bluk-Only"],
    [0x08, 0x06, 0x50, "MassStorage SCSI Bluk-Only"],
    [0x08, nil, nil, "MassStorage"],
    [0x09, 0x00, 0x00, "Full speed Hub"],
    [0x09, 0x00, 0x01, "Hi-speed Hub with single TT"],
    [0x09, 0x00, 0x02, "Hi-speed Hub with multiple TTs"],
    [0x09, nil, nil, "Hub"],
    [0x0a, nil, nil, "CDC"],
    [0x0b, nil, nil, "SmartCard"],
    [0x0d, 0x00, 0x00, "ContentSecurity"],
    [0x0e, nil, nil, "Video"],
    [0xdc, 0x01, 0x01, "Diagnostic USB2"],
    [0xdc, nil, nil, "Diagnostic"],
    [0xe0, 0x01, 0x01, "Bluetooth"],
    [0xe0, 0x01, 0x02, "UWB"],
    [0xe0, 0x01, 0x03, "RemoteNDIS"],
    [0xe0, 0x02, 0x01, "Host Wire Adapter Control/Data"],
    [0xe0, 0x02, 0x02, "Device Wire Adapter Control/Data"],
    [0xe0, 0x02, 0x03, "Device Wire Adapter Isochronous"],
    [0xe0, nil, nil, "Wireless Controller"],
    [0xef, 0x01, 0x01, "Active Sync"],
    [0xef, 0x01, 0x02, "Palm Sync"],
    [0xef, 0x02, 0x01, "Interface Association Descriptor"],
    [0xef, 0x02, 0x02, "Wire Adapter Multifunction Peripheral"],
    [0xef, 0x03, 0x01, "Cable Based Association Framework"],
    [0xef, nil, nil, "Miscellaneous"],
    [0xfe, 0x01, 0x01, "Device Firmware Upgrade"],
    [0xfe, 0x02, 0x00, "IRDA Bridge"],
    [0xfe, 0x03, 0x00, "USB Test and Measurement"],
    [0xfe, 0x03, 0x01, "USB Test and Measurement (USBTMC USB488)"],
    [0xfe, nil, nil, "Application Specific"],
    [0xff, nil, nil, "Vendor specific"],
  ]
  CLASS_CODES_HASH1 = {}
  CLASS_CODES_HASH2 = {}
  CLASS_CODES_HASH3 = {}
  CLASS_CODES.each {|base_class, sub_class, protocol, desc|
    if protocol
      CLASS_CODES_HASH3[[base_class, sub_class, protocol]] = desc
    elsif sub_class
      CLASS_CODES_HASH2[[base_class, sub_class]] = desc
    else
      CLASS_CODES_HASH1[base_class] = desc
    end
  }

  def self.dev_string(base_class, sub_class, protocol)
    if desc = CLASS_CODES_HASH3[[base_class, sub_class, protocol]]
      desc
    elsif desc = CLASS_CODES_HASH2[[base_class, sub_class]]
      desc + " (%02x)" % [protocol]
    elsif desc = CLASS_CODES_HASH1[base_class]
      desc + " (%02x,%02x)" % [sub_class, protocol]
    else
      "Unkonwn(%02x,%02x,%02x)" % [base_class, sub_class, protocol]
    end
  end
  # :startdoc:

  class Device
    include Comparable

    def inspect
      attrs = []
      attrs << "#{self.busNumber}/#{self.deviceAddress}"
      attrs << ("%04x:%04x" % [self.idVendor, self.idProduct])
      attrs << self.manufacturer
      attrs << self.product
      attrs << self.serial_number
      if self.bDeviceClass == LIBUSB_CLASS_PER_INTERFACE
        devclass = self.interface_descriptors.map {|i|
          RibUSB.dev_string(i.bInterfaceClass, i.bInterfaceSubClass, i.bInterfaceProtocol)
        }.join(", ")
      else
        devclass = RibUSB.dev_string(self.bDeviceClass, self.bDeviceSubClass, self.bDeviceProtocol)
      end
      attrs << "(#{devclass})"
      attrs.compact!
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    def tryStringDescriptorASCII(i)
      begin
        getStringDescriptorASCII(i)
      rescue
        "?"
      end
    end

    def manufacturer
      return @manufacturer if defined? @manufacturer
      @manufacturer = tryStringDescriptorASCII(self.iManufacturer)
      @manufacturer.strip! if @manufacturer
      @manufacturer
    end

    def product
      return @product if defined? @product
      @product = tryStringDescriptorASCII(self.iProduct)
      @product.strip! if @product
      @product
    end

    def serial_number
      return @serial_number if defined? @serial_number
      @serial_number = tryStringDescriptorASCII(self.iSerialNumber)
      @serial_number.strip! if @serial_number
      @serial_number
    end

    def configurations
      configs = []
      bNumConfigurations.times do |config_index|
        configs << configDescriptor(config_index)
      end
      configs
    end

    def interfaces() self.configurations.map {|d| d.interfaces }.flatten end
    def interface_descriptors() self.interfaces.map {|d| d.altSettings }.flatten end
    def endpoints() self.interface_descriptors.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = busNumber<=>o.busNumber
      t = deviceAddress<=>o.deviceAddress if t==0
      t
    end
  end

  class ConfigDescriptor
    include Comparable

    def inspect
      attrs = []
      attrs << self.bConfigurationValue.to_s
      bits = self.bmAttributes
      attrs << "SelfPowered" if (bits & 0b1000000) != 0
      attrs << "RemoteWakeup" if (bits & 0b100000) != 0
      desc = self.description
      attrs << desc if desc != '?'
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    def description
      return @description if defined? @description
      @description = device.tryStringDescriptorASCII(self.iConfiguration)
    end

    def interface_descriptors() self.interfaces.map {|d| d.altSettings }.flatten end
    def endpoints() self.interface_descriptors.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = device<=>o.device
      t = bConfigurationValue<=>o.bConfigurationValue if t==0
      t
    end
  end

  class Interface
    include Comparable

    def device() self.configuration.device end
    def endpoints() self.altSettings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      configuration<=>o.configuration
    end
  end

  class InterfaceDescriptor
    include Comparable

    def inspect
      attrs = []
      attrs << self.bAlternateSetting.to_s
      devclass = RibUSB.dev_string(self.bInterfaceClass, self.bInterfaceSubClass, self.bInterfaceProtocol)
      attrs << devclass
      desc = self.description
      attrs << desc if desc != '?'
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    def description
      return @description if defined? @description
      @description = device.tryStringDescriptorASCII(self.iInterface)
    end

    def device() self.interface.configuration.device end
    def configuration() self.interface.configuration end

    def <=>(o)
      t = interface<=>o.interface
      t = bInterfaceNumber<=>o.bInterfaceNumber if t==0
      t = bAlternateSetting<=>o.bAlternateSetting if t==0
      t
    end
  end

  class EndpointDescriptor
    include Comparable

    def inspect
      endpoint_address = self.bEndpointAddress
      num = endpoint_address & 0b00001111
      inout = (endpoint_address & 0b10000000) == 0 ? "OUT" : "IN "
      bits = self.bmAttributes
      transfer_type = %w[Control Isochronous Bulk Interrupt][0b11 & bits]
      type = [transfer_type]
      if transfer_type == 'Isochronous'
        synchronization_type = %w[NoSynchronization Asynchronous Adaptive Synchronous][(0b1100 & bits) >> 2]
        usage_type = %w[Data Feedback ImplicitFeedback ?][(0b110000 & bits) >> 4]
        type << synchronization_type << usage_type
      end
      "\#<#{self.class} #{num} #{inout} #{type.join(" ")}>"
    end

    def device() self.interface_descriptor.interface.configuration.device end
    def configuration() self.interface_descriptor.interface.configuration end
    def interface() self.interface_descriptor.interface end

    def <=>(o)
      t = interface_descriptor<=>o.interface_descriptor
      t = bEndpointAddress<=>o.bEndpointAddress if t==0
      t
    end
  end

end
