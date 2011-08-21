require 'rubygems'
require 'ffi'

module LIBUSB
  module Call
    extend FFI::Library
    ffi_lib 'libusb-1.0'
    
    attach_function 'libusb_init', [ :pointer ], :int
    attach_function 'libusb_exit', [ :pointer ], :void
    attach_function 'libusb_set_debug', [:pointer, :int], :void

    attach_function 'libusb_get_device_list', [:pointer, :pointer], :size_t
    attach_function 'libusb_free_device_list', [:pointer, :int], :void
    attach_function 'libusb_ref_device', [:pointer], :pointer
    attach_function 'libusb_unref_device', [:pointer], :void

    attach_function 'libusb_get_device_descriptor', [:pointer, :pointer], :int
    attach_function 'libusb_get_active_config_descriptor', [:pointer, :pointer], :int
    attach_function 'libusb_get_config_descriptor', [:pointer, :uint8, :pointer], :int
    attach_function 'libusb_get_config_descriptor_by_value', [:pointer, :uint8, :pointer], :int
    attach_function 'libusb_free_config_descriptor', [:pointer], :void
    attach_function 'libusb_get_bus_number', [:pointer], :uint8
    attach_function 'libusb_get_device_address', [:pointer], :uint8
    attach_function 'libusb_get_max_packet_size', [:pointer, :uint8], :int
    attach_function 'libusb_get_max_iso_packet_size', [:pointer, :uint8], :int

    attach_function 'libusb_open', [:pointer, :pointer], :int
    attach_function 'libusb_close', [:pointer], :void
    attach_function 'libusb_get_device', [:pointer], :pointer

    attach_function 'libusb_get_string_descriptor_ascii', [:pointer, :uint8, :pointer, :int], :int

    ClassCode = enum :libusb_class_code, [
      :CLASS_PER_INTERFACE, 0,
      :CLASS_AUDIO, 1,
      :CLASS_COMM, 2,
      :CLASS_HID, 3,
      :CLASS_PRINTER, 7,
      :CLASS_PTP, 6,
      :CLASS_MASS_STORAGE, 8,
      :CLASS_HUB, 9,
      :CLASS_DATA, 10,
      :CLASS_WIRELESS, 0xe0,
      :CLASS_APPLICATION, 0xfe,
      :CLASS_VENDOR_SPEC, 0xff
    ]
  end
  Call::ClassCode.to_h.each{|k,v| const_set(k,v) }

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
  

  class DeviceDescriptor < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bcdUSB, :uint16,
        :bDeviceClass, :uint8,
        :bDeviceSubClass, :uint8,
        :bDeviceProtocol, :uint8,
        :bMaxPacketSize0, :uint8,
        :idVendor, :uint16,
        :idProduct, :uint16,
        :bcdDevice, :uint16,
        :iManufacturer, :uint8,
        :iProduct, :uint8,
        :iSerialNumber, :uint8,
        :bNumConfigurations, :uint8
  end

  class Configuration < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :wTotalLength, :uint16,
        :bNumInterfaces, :uint8,
        :bConfigurationValue, :uint8,
        :iConfiguration, :uint8,
        :bmAttributes, :uint8,
        :maxPower, :uint8,
        :interface, :pointer,
        :extra, :pointer,
        :extra_length, :int

    members.each do |member|
      define_method(member) do
        self[member]
      end
    end

    def initialize(device, *args)
      @device = device
      super(*args)
    end

    attr_reader :device

    def interfaces
      ifs = []
      self[:bNumInterfaces].times do |i|
        ifs << Interface.new(self, self[:interface] + i*Interface.size)
      end
      return ifs
    end

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

    # Return name of the configuration as String.
    def description
      return @description if defined? @description
      @description = device.try_string_descriptor_ascii(self.iConfiguration)
    end

    # Return all interface decriptions of the configuration as Array of InterfaceDescriptor s.
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    # Return all endpoints of all interfaces of the configuration as Array of EndpointDescriptor s.
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = device<=>o.device
      t = bConfigurationValue<=>o.bConfigurationValue if t==0
      t
    end
  end

  class Interface < FFI::Struct
    include Comparable

    layout :altsetting, :pointer,
        :num_altsetting, :int

    def initialize(configuration, *args)
      @configuration = configuration
      super(*args)
    end

    attr_reader :configuration

    def settings
      ifs = []
      self[:num_altsetting].times do |i|
        ifs << Setting.new(self, self[:altsetting] + i*Setting.size)
      end
      return ifs
    end
    # The Device the Interface belongs to.
    def device() self.configuration.device end
    # Return all endpoints of all alternative settings as Array of EndpointDescriptor s.
    def endpoints() self.alt_settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      configuration<=>o.configuration
    end
  end

  class Setting < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bInterfaceNumber, :uint8,
        :bAlternateSetting, :uint8,
        :bNumEndpoints, :uint8,
        :bInterfaceClass, :uint8,
        :bInterfaceSubClass, :uint8,
        :bInterfaceProtocol, :uint8,
        :iInterface, :uint8,
        :endpoint, :pointer,
        :extra, :pointer,
        :extra_length, :int

    members.each do |member|
      define_method(member) do
        self[member]
      end
    end

    def initialize(interface, *args)
      @interface = interface
      super(*args)
    end

    attr_reader :interface

    def endpoints
      ifs = []
      self[:bNumEndpoints].times do |i|
        ifs << Endpoint.new(self, self[:endpoint] + i*Endpoint.size)
      end
      return ifs
    end

    def inspect
      attrs = []
      attrs << self.bAlternateSetting.to_s
      devclass = LIBUSB.dev_string(self.bInterfaceClass, self.bInterfaceSubClass, self.bInterfaceProtocol)
      attrs << devclass
      desc = self.description
      attrs << desc if desc != '?'
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    # Return name of the Interface as String.
    def description
      return @description if defined? @description
      @description = device.try_string_descriptor_ascii(self.iInterface)
    end

    # The Device the InterfaceDescriptor belongs to.
    def device() self.interface.configuration.device end
    # The ConfigDescriptor the InterfaceDescriptor belongs to.
    def configuration() self.interface.configuration end

    def <=>(o)
      t = interface<=>o.interface
      t = bInterfaceNumber<=>o.bInterfaceNumber if t==0
      t = bAlternateSetting<=>o.bAlternateSetting if t==0
      t
    end
  end

  class Endpoint < FFI::Struct
    include Comparable

    layout :bLength, :uint8,
        :bDescriptorType, :uint8,
        :bEndpointAddress, :uint8,
        :bmAttributes, :uint8,
        :wMaxPacketSize, :uint16,
        :bInterval, :uint8,
        :bRefresh, :uint8,
        :bSynchAddress, :uint8,
        :extra, :pointer,
        :extra_length, :int

    members.each do |member|
      define_method(member) do
        self[member]
      end
    end

    def initialize(setting, *args)
      @setting = setting
      super(*args)
    end

    attr_reader :setting

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

    # The Device the EndpointDescriptor belongs to.
    def device() self.interface_descriptor.interface.configuration.device end
    # The ConfigDescriptor the EndpointDescriptor belongs to.
    def configuration() self.interface_descriptor.interface.configuration end
    # The Interface the EndpointDescriptor belongs to.
    def interface() self.interface_descriptor.interface end

    def <=>(o)
      t = interface_descriptor<=>o.interface_descriptor
      t = bEndpointAddress<=>o.bEndpointAddress if t==0
      t
    end
  end


  
  class Context
    def initialize
      m = FFI::MemoryPointer.new :pointer
      Call.libusb_init(m)
      @ctx = m.read_pointer
    end

    def exit
      Call.libusb_exit(@ctx)
    end

    def device_list
      pppDevs = FFI::MemoryPointer.new :pointer
      size = Call.libusb_get_device_list(@ctx, pppDevs)
      ppDevs = pppDevs.read_pointer
      pDevs = []
      size.times do |devi|
        pDev = ppDevs.get_pointer(devi*FFI.type_size(:pointer))
        pDevs << Device.new(pDev)
      end
      Call.libusb_free_device_list(ppDevs, 1)
      pDevs
    end
  end

  class Device
    include Comparable

    def initialize pDev
      class << pDev
        def unref_device
          Call.libusb_unref_device(self)
        end
      end
      ObjectSpace.define_finalizer(self, pDev.method(:unref_device))
      Call.libusb_ref_device(pDev)
      @pDev = pDev

      @pDevDesc = DeviceDescriptor.new
      res = Call.libusb_get_device_descriptor(@pDev, @pDevDesc)
      raise "error #{res} in libusb_get_device_descriptor" unless res==0
    end

    def open
      ppHandle = FFI::MemoryPointer.new :pointer
      res = Call.libusb_open(@pDev, ppHandle)
      raise "error #{res} in libusb_open" unless res==0
      handle = Handle.new ppHandle.read_pointer
      return yield handle if block_given?
      handle
    end

    def bus_number
      Call.libusb_get_bus_number(@pDev)
    end
    def device_address
      Call.libusb_get_device_address(@pDev)
    end
    def max_packet_size(endpoint)
      Call.libusb_get_max_packet_size(@pDev, endpoint)
    end
    def max_iso_packet_size(endpoint)
      Call.libusb_get_max_iso_packet_size(@pDev, endpoint)
    end

    def config_descriptor(index)
      ppConfig = FFI::MemoryPointer.new :pointer
      Call.libusb_get_config_descriptor(@pDev, index, ppConfig)
      pConfig = ppConfig.read_pointer
      class << pConfig
        def free_config
          Call.libusb_free_config_descriptor(self)
        end
      end
      config = Configuration.new(self, pConfig)
      ObjectSpace.define_finalizer(config, pConfig.method(:free_config))
      config
    end

    # allow access to Descriptor members on Device
    DeviceDescriptor.members.each do |member|
      define_method(member) do
        @pDevDesc[member]
      end
    end

    def inspect
      attrs = []
      attrs << "#{self.bus_number}/#{self.device_address}"
      attrs << ("%04x:%04x" % [self.idVendor, self.idProduct])
      attrs << self.manufacturer
      attrs << self.product
      attrs << self.serial_number
      if self.bDeviceClass == LIBUSB::CLASS_PER_INTERFACE
        devclass = self.interface_descriptors.map {|i|
          LIBUSB.dev_string(i.bInterfaceClass, i.bInterfaceSubClass, i.bInterfaceProtocol)
        }.join(", ")
      else
        devclass = LIBUSB.dev_string(self.bDeviceClass, self.bDeviceSubClass, self.bDeviceProtocol)
      end
      attrs << "(#{devclass})"
      attrs.compact!
      "\#<#{self.class} #{attrs.join(' ')}>"
    end

    def try_string_descriptor_ascii(i)
      begin
        open{|h| h.string_descriptor_ascii(i) }
      rescue
        "?"
      end
    end

    # Return manufacturer of the device as String.
    def manufacturer
      return @manufacturer if defined? @manufacturer
      @manufacturer = try_string_descriptor_ascii(self.iManufacturer)
      @manufacturer.strip! if @manufacturer
      @manufacturer
    end

    # Return product name of the device as String.
    def product
      return @product if defined? @product
      @product = try_string_descriptor_ascii(self.iProduct)
      @product.strip! if @product
      @product
    end

    # Return serial number of the device as String.
    def serial_number
      return @serial_number if defined? @serial_number
      @serial_number = try_string_descriptor_ascii(self.iSerialNumber)
      @serial_number.strip! if @serial_number
      @serial_number
    end

    # Return configurations of the device as Array of Configuration s.
    def configurations
      configs = []
      bNumConfigurations.times do |config_index|
        begin
          configs << config_descriptor(config_index)
        rescue RuntimeError
          # On Windows some devices don't return it's configuration.
        end
      end
      configs
    end

    # Return all interfaces of the device as Array of Interface s.
    def interfaces() self.configurations.map {|d| d.interfaces }.flatten end
    # Return all interface decriptions of the device as Array of InterfaceDescriptor s.
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    # Return all endpoints of all interfaces of the device as Array of EndpointDescriptor s.
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = bus_number<=>o.bus_number
      t = device_address<=>o.device_address if t==0
      t
    end
  end

  class Handle
    def initialize pHandle
      @pHandle = pHandle
    end

    def close
      Call.libusb_close(@pHandle)
    end

    def string_descriptor_ascii(index)
      pString = FFI::MemoryPointer.new 0x100
      res = Call.libusb_get_string_descriptor_ascii(@pHandle, index, pString, pString.size)
      raise "error #{res} in libusb_get_string_descriptor_ascii" if res<0
      pString.read_string(res)
    end
  end

end

c = LIBUSB::Context.new
devs = c.device_list
dev = devs[0]
p dev
h = dev.open
p h
h.close
p dev.configurations
p dev.interfaces
p dev.settings
p dev.endpoints

c.exit
