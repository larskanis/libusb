# This file is part of Libusb for Ruby.
#
# Libusb for Ruby is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Libusb for Ruby is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Libusb for Ruby.  If not, see <http://www.gnu.org/licenses/>.

require 'rubygems'
require 'ffi'


module LIBUSB
  VERSION = "0.1.2"

  module Call
    extend FFI::Library
    if RUBY_PLATFORM=~/mingw|mswin/i
      bundled_dll = File.join(File.dirname(__FILE__), 'libusb-1.0.dll')
      ffi_lib(['libusb-1.0', bundled_dll])
    else
      ffi_lib 'libusb-1.0'
    end

    ClassCodes = enum :libusb_class_code, [
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

    Errors = enum :libusb_error, [
      :SUCCESS, 0,
      :ERROR_IO, -1,
      :ERROR_INVALID_PARAM, -2,
      :ERROR_ACCESS, -3,
      :ERROR_NO_DEVICE, -4,
      :ERROR_NOT_FOUND, -5,
      :ERROR_BUSY, -6,
      :ERROR_TIMEOUT, -7,
      :ERROR_OVERFLOW, -8,
      :ERROR_PIPE, -9,
      :ERROR_INTERRUPTED, -10,
      :ERROR_NO_MEM, -11,
      :ERROR_NOT_SUPPORTED, -12,
      :ERROR_OTHER, -99,
    ]

    # Transfer status codes
    TransferStatus = enum :libusb_transfer_status, [
      :TRANSFER_COMPLETED,
      :TRANSFER_ERROR,
      :TRANSFER_TIMED_OUT,
      :TRANSFER_CANCELLED,
      :TRANSFER_STALL,
      :TRANSFER_NO_DEVICE,
      :TRANSFER_OVERFLOW,
    ]

    # libusb_transfer.flags values
    TransferFlags = enum :libusb_transfer_flags, [
      :TRANSFER_SHORT_NOT_OK, 1 << 0,
      :TRANSFER_FREE_BUFFER, 1 << 1,
      :TRANSFER_FREE_TRANSFER, 1 << 2,
    ]

    TransferTypes = enum :libusb_transfer_type, [
      :TRANSFER_TYPE_CONTROL, 0,
      :TRANSFER_TYPE_ISOCHRONOUS, 1,
      :TRANSFER_TYPE_BULK, 2,
      :TRANSFER_TYPE_INTERRUPT, 3,
    ]

    StandardRequests = enum :libusb_standard_request, [
      :REQUEST_GET_STATUS, 0x00,
      :REQUEST_CLEAR_FEATURE, 0x01,
      :REQUEST_SET_FEATURE, 0x03,
      :REQUEST_SET_ADDRESS, 0x05,
      :REQUEST_GET_DESCRIPTOR, 0x06,
      :REQUEST_SET_DESCRIPTOR, 0x07,
      :REQUEST_GET_CONFIGURATION, 0x08,
      :REQUEST_SET_CONFIGURATION, 0x09,
      :REQUEST_GET_INTERFACE, 0x0A,
      :REQUEST_SET_INTERFACE, 0x0B,
      :REQUEST_SYNCH_FRAME, 0x0C,
    ]

    EndpointDirections = enum :libusb_endpoint_direction, [
      :ENDPOINT_IN, 0x80,
      :ENDPOINT_OUT, 0x00,
    ]

    DescriptorTypes = enum :libusb_descriptor_type, [
      :DT_DEVICE, 0x01,
      :DT_CONFIG, 0x02,
      :DT_STRING, 0x03,
      :DT_INTERFACE, 0x04,
      :DT_ENDPOINT, 0x05,
      :DT_HID, 0x21,
      :DT_REPORT, 0x22,
      :DT_PHYSICAL, 0x23,
      :DT_HUB, 0x29,
    ]

    RequestTypes = enum :libusb_request_type, [
      :REQUEST_TYPE_STANDARD, (0x00 << 5),
      :REQUEST_TYPE_CLASS, (0x01 << 5),
      :REQUEST_TYPE_VENDOR, (0x02 << 5),
      :REQUEST_TYPE_RESERVED, (0x03 << 5),
    ]

    RequestRecipients = enum :libusb_request_recipient, [
      :RECIPIENT_DEVICE, 0x00,
      :RECIPIENT_INTERFACE, 0x01,
      :RECIPIENT_ENDPOINT, 0x02,
      :RECIPIENT_OTHER, 0x03,
    ]

    IsoSyncTypes = enum :libusb_iso_sync_type, [
      :ISO_SYNC_TYPE_NONE, 0,
      :ISO_SYNC_TYPE_ASYNC, 1,
      :ISO_SYNC_TYPE_ADAPTIVE, 2,
      :ISO_SYNC_TYPE_SYNC, 3,
    ]


    typedef :pointer, :libusb_context
    typedef :pointer, :libusb_device_handle

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
    attach_function 'libusb_get_device', [:libusb_device_handle], :pointer

    attach_function 'libusb_set_configuration', [:libusb_device_handle, :int], :int, :blocking=>true
    attach_function 'libusb_claim_interface', [:libusb_device_handle, :int], :int
    attach_function 'libusb_release_interface', [:libusb_device_handle, :int], :int, :blocking=>true

    attach_function 'libusb_open_device_with_vid_pid', [:pointer, :int, :int], :pointer

    attach_function 'libusb_set_interface_alt_setting', [:libusb_device_handle, :int, :int], :int, :blocking=>true
    attach_function 'libusb_clear_halt', [:libusb_device_handle, :int], :int, :blocking=>true
    attach_function 'libusb_reset_device', [:libusb_device_handle], :int, :blocking=>true

    attach_function 'libusb_kernel_driver_active', [:libusb_device_handle, :int], :int
    attach_function 'libusb_detach_kernel_driver', [:libusb_device_handle, :int], :int
    attach_function 'libusb_attach_kernel_driver', [:libusb_device_handle, :int], :int

    attach_function 'libusb_get_string_descriptor_ascii', [:pointer, :uint8, :pointer, :int], :int

    attach_function 'libusb_alloc_transfer', [:int], :pointer
    attach_function 'libusb_submit_transfer', [:pointer], :int
    attach_function 'libusb_cancel_transfer', [:pointer], :int
    attach_function 'libusb_free_transfer', [:pointer], :void

    attach_function 'libusb_handle_events', [:libusb_context], :int, :blocking=>true


    callback :libusb_transfer_cb_fn, [:pointer], :void

    class IsoPacketDescriptor < FFI::Struct
      layout :length, :uint,
          :actual_length, :uint,
          :status, :libusb_transfer_status
    end

    # Setup packet for control transfers.
    class ControlSetup < FFI::Struct
      layout :bmRequestType, :uint8,
          :bRequest, :uint8,
          :wValue, :uint16,
          :wIndex, :uint16,
          :wLength, :uint16
    end

    class Transfer < FFI::ManagedStruct
      layout :dev_handle, :libusb_device_handle,
        :flags, :uint8,
        :endpoint, :uchar,
        :type, :uchar,
        :timeout, :uint,
        :status, :libusb_transfer_status,
        :length, :int,
        :actual_length, :int,
        :callback, :libusb_transfer_cb_fn,
        :user_data, :pointer,
        :buffer, :pointer,
        :num_iso_packets, :int

      def self.release(ptr)
        Call.libusb_free_transfer(ptr)
      end
    end
  end

  Call::ClassCodes.to_h.each{|k,v| const_set(k,v) }
  Call::TransferTypes.to_h.each{|k,v| const_set(k,v) }
  Call::StandardRequests.to_h.each{|k,v| const_set(k,v) }
  Call::RequestTypes.to_h.each{|k,v| const_set(k,v) }
  Call::DescriptorTypes.to_h.each{|k,v| const_set(k,v) }
  Call::EndpointDirections.to_h.each{|k,v| const_set(k,v) }
  Call::RequestRecipients.to_h.each{|k,v| const_set(k,v) }
  Call::IsoSyncTypes.to_h.each{|k,v| const_set(k,v) }

  class Error < RuntimeError
  end
  ErrorClassForResult = {}

  # define an exception class for each error code
  Call::Errors.to_h.each do |k,v|
    klass = Class.new(Error)
    klass.send(:define_method, :code){ v }
    const_set(k, klass)
    ErrorClassForResult[v] = klass
  end

  def self.raise_error(res, text)
    klass = ErrorClassForResult[res]
    raise klass, "#{klass} #{text}"
  end

  CONTROL_SETUP_SIZE = 8
  DT_DEVICE_SIZE = 18
  DT_CONFIG_SIZE = 9
  DT_INTERFACE_SIZE = 9
  DT_ENDPOINT_SIZE = 7
  DT_ENDPOINT_AUDIO_SIZE = 9 # Audio extension
  DT_HUB_NONVAR_SIZE = 7

  ENDPOINT_ADDRESS_MASK = 0x0f    # in bEndpointAddress
  ENDPOINT_DIR_MASK = 0x80
  TRANSFER_TYPE_MASK = 0x03    # in bmAttributes
  ISO_SYNC_TYPE_MASK = 0x0C
  ISO_USAGE_TYPE_MASK = 0x30


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


  # Abstract base class for USB transfers. Use
  # {ControlTransfer}, {BulkTransfer}, {InterruptTransfer}, {IsochronousTransfer}
  # to do transfers.
  class Transfer
    def initialize(args={})
      args.each{|k,v| send("#{k}=", v) }
      @buffer = nil
    end
    private :initialize

    # Set the handle for the device to communicate with.
    def dev_handle=(dev)
      @dev_handle = dev
      @transfer[:dev_handle] = @dev_handle.pHandle
    end

    # Timeout for this transfer in millseconds.
    #
    # A value of 0 indicates no timeout.
    def timeout=(value)
      @transfer[:timeout] = value
    end

    # Set the address of a valid endpoint to communicate with.
    def endpoint=(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      @transfer[:endpoint] = endpoint
    end

    # Set output data that should be sent.
    def buffer=(data)
      if !@buffer || data.bytesize>@buffer.size
        free_buffer
        @buffer = FFI::MemoryPointer.new(data.bytesize, 1, false)
      end
      @buffer.put_bytes(0, data)
      @transfer[:buffer] = @buffer
      @transfer[:length] = data.bytesize
    end

    # Retrieve the current data buffer.
    def buffer
      @transfer[:buffer].read_string(@transfer[:length])
    end

    # Clear the current data buffer.
    def free_buffer
      if @buffer
        @buffer.free
        @buffer = nil
        @transfer[:buffer] = nil
        @transfer[:length] = 0
      end
    end

    # Allocate +len+ bytes of data buffer for input transfer.
    #
    # @param [Fixnum]  len  Number of bytes to allocate
    # @param [String, nil] data  some data to initialize the buffer with
    def alloc_buffer(len, data=nil)
      if !@buffer || len>@buffer.size
        free_buffer
        @buffer = FFI::MemoryPointer.new(len, 1, false)
      end
      @buffer.put_bytes(0, data) if data
      @transfer[:buffer] = @buffer
      @transfer[:length] = len
    end

    # The number of bytes actually transferred.
    def actual_length
      @transfer[:actual_length]
    end

    # Retrieve the data actually transferred.
    #
    # @param [Fixnum] offset  optional offset of the retrieved data in the buffer.
    def actual_buffer(offset=0)
      @transfer[:buffer].get_bytes(offset, @transfer[:actual_length])
    end

    # Set the block that will be invoked when the transfer completes,
    # fails, or is cancelled.
    #
    # @param [Proc] proc  The block that should be called
    def callback=(proc)
      # Save proc to instance variable so that GC doesn't free
      # the proc object before the transfer.
      @callback_proc = proc do |pTrans|
        proc.call(self)
      end
      @transfer[:callback] = @callback_proc
    end

    # The status of the transfer.
    #
    # Only for use within transfer callback function or after the callback was called.
    #
    # If this is an isochronous transfer, this field may read :TRANSFER_COMPLETED even if there
    # were errors in the frames. Use the status field in each packet to determine if
    # errors occurred.
    def status
      @transfer[:status]
    end

    # Submit a transfer.
    #
    # This function will fire off the USB transfer and then return immediately.
    # This method can be called with block. It is called when the transfer completes,
    # fails, or is cancelled.
    def submit!(&block)
      self.callback = block if block_given?

#       puts "submit transfer #{@transfer.inspect} buffer: #{@transfer[:buffer].inspect} length: #{@transfer[:length].inspect} status: #{@transfer[:status].inspect} callback: #{@transfer[:callback].inspect} dev_handle: #{@transfer[:dev_handle].inspect}"

      res = Call.libusb_submit_transfer( @transfer )
      LIBUSB.raise_error res, "in libusb_submit_transfer" if res!=0
    end

    # Asynchronously cancel a previously submitted transfer.
    #
    # This function returns immediately, but this does not indicate cancellation is
    # complete. Your callback function will be invoked at some later time with a
    # transfer status of :TRANSFER_CANCELLED.
    def cancel!
      res = Call.libusb_cancel_transfer( @transfer )
      LIBUSB.raise_error res, "in libusb_cancel_transfer" if res!=0
    end

    TransferStatusToError = {
      :TRANSFER_ERROR => LIBUSB::ERROR_IO,
      :TRANSFER_TIMED_OUT => LIBUSB::ERROR_TIMEOUT,
      :TRANSFER_CANCELLED => LIBUSB::ERROR_INTERRUPTED,
      :TRANSFER_STALL => LIBUSB::ERROR_PIPE,
      :TRANSFER_NO_DEVICE => LIBUSB::ERROR_NO_DEVICE,
      :TRANSFER_OVERFLOW => LIBUSB::ERROR_OVERFLOW,
    }

    # Submit the transfer and wait until the transfer completes or fails.
    #
    # A proper {LIBUSB::Error} is raised, in case the transfer did not complete.
    def submit_and_wait!
      completed = false
      submit! do |tr2|
        completed = true
      end

      until completed
        begin
          @dev_handle.device.context.handle_events
        rescue ERROR_INTERRUPTED
          next
        rescue LIBUSB::Error
          cancel!
          until completed
            @dev_handle.device.context.handle_events
          end
          raise
        end
      end

      raise( TransferStatusToError[status] || ERROR_OTHER, "error #{status}") unless status==:TRANSFER_COMPLETED
    end
  end

  class BulkTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_BULK
      @transfer[:timeout] = 1000
      super
    end
  end

  class ControlTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_CONTROL
      @transfer[:timeout] = 1000
      super
    end
  end

  class InterruptTransfer < Transfer
    def initialize(args={})
      @transfer = Call::Transfer.new Call.libusb_alloc_transfer(0)
      @transfer[:type] = TRANSFER_TYPE_INTERRUPT
      @transfer[:timeout] = 1000
      super
    end
  end

  class IsoPacket
    def initialize(ptr, pkg_nr)
      @packet = Call::IsoPacketDescriptor.new ptr
      @pkg_nr = pkg_nr
    end

    def status
      @packet[:status]
    end

    def length
      @packet[:length]
    end
    def length=(len)
      @packet[:length] = len
    end

    def actual_length
      @packet[:actual_length]
    end
  end

  class IsochronousTransfer < Transfer
    def initialize(num_packets, args={})
      @ptr = Call.libusb_alloc_transfer(num_packets)
      @transfer = Call::Transfer.new @ptr
      @transfer[:type] = TRANSFER_TYPE_ISOCHRONOUS
      @transfer[:timeout] = 1000
      @transfer[:num_iso_packets] = num_packets
      super(args)
    end

    def num_packets
      @transfer[:num_iso_packets]
    end
    def num_packets=(number)
      @transfer[:num_iso_packets] = number
    end

    def [](nr)
      IsoPacket.new( @ptr + Call::Transfer.size + nr*Call::IsoPacketDescriptor.size, nr)
    end

    # Convenience function to set the length of all packets in an
    # isochronous transfer, based on {IsochronousTransfer#num_packets}.
    def packet_lengths=(len)
      ptr = @ptr + Call::Transfer.size
      num_packets.times do
        ptr.write_uint(len)
        ptr += Call::IsoPacketDescriptor.size
      end
    end

    # The actual_length field of the transfer is meaningless and should not
    # be examined; instead you must refer to the actual_length field of
    # each individual packet.
    private :actual_length, :actual_buffer
  end

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

  class Configuration < FFI::ManagedStruct
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

    # Size of this descriptor (in bytes).
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x02)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # Total length of data returned for this configuration.
    def wTotalLength
      self[:wTotalLength]
    end

    # Number of interfaces supported by this configuration.
    def bNumInterfaces
      self[:bNumInterfaces]
    end

    # Identifier value for this configuration.
    def bConfigurationValue
      self[:bConfigurationValue]
    end

    # Index of string descriptor describing this configuration.
    def iConfiguration
      self[:iConfiguration]
    end

    # Configuration characteristics.
    #
    # * Bit 7: Reserved, set to 1. (USB 1.0 Bus Powered)
    # * Bit 6: Self Powered
    # * Bit 5: Remote Wakeup
    # * Bit 4..0: Reserved, set to 0.
    #
    # @return [Integer]
    def bmAttributes
      self[:bmAttributes]
    end

    # Maximum power consumption of the USB device from this bus in this configuration when the device is fully opreation.
    #
    # @result [Integer] Maximum Power Consumption in 2mA units
    def maxPower
      self[:maxPower]
    end

    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(device, *args)
      @device = device
      super(*args)
    end

    def self.release(ptr)
      Call.libusb_free_config_descriptor(ptr)
    end

    # @return [Device] the device this configuration belongs to.
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

    # @return [Configuration] the configuration this interface belongs to.
    attr_reader :configuration

    def alt_settings
      ifs = []
      self[:num_altsetting].times do |i|
        ifs << Setting.new(self, self[:altsetting] + i*Setting.size)
      end
      return ifs
    end
    alias settings alt_settings

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

    # Size of this descriptor (in bytes).
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x04)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # Number of this interface.
    def bInterfaceNumber
      self[:bInterfaceNumber]
    end

    # Value used to select this alternate setting for this interface.
    def bAlternateSetting
      self[:bAlternateSetting]
    end

    # Number of endpoints used by this interface (excluding the control endpoint).
    def bNumEndpoints
      self[:bNumEndpoints]
    end

    # USB-IF class code for this interface.
    def bInterfaceClass
      self[:bInterfaceClass]
    end

    # USB-IF subclass code for this interface, qualified by the bInterfaceClass value.
    def bInterfaceSubClass
      self[:bInterfaceSubClass]
    end

    # USB-IF protocol code for this interface, qualified by the bInterfaceClass and bInterfaceSubClass values.
    def bInterfaceProtocol
      self[:bInterfaceProtocol]
    end

    # Index of string descriptor describing this interface.
    def iInterface
      self[:iInterface]
    end

    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(interface, *args)
      @interface = interface
      super(*args)
    end

    # @return [Interface] the interface this setting belongs to.
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

    # Size of Descriptor in Bytes (7 bytes)
    def bLength
      self[:bLength]
    end

    # Descriptor type (0x05)
    def bDescriptorType
      self[:bDescriptorType]
    end

    # The address of the endpoint described by this descriptor.
    #
    # * Bits 0..3: Endpoint Number.
    # * Bits 4..6: Reserved. Set to Zero
    # * Bits 7: Direction 0 = Out, 1 = In (Ignored for Control Endpoints)
    #
    # @return [Integer]
    def bEndpointAddress
      self[:bEndpointAddress]
    end

    # Attributes which apply to the endpoint when it is configured using the bConfigurationValue.
    #
    # * Bits 0..1: Transfer Type
    #   * 00 = Control
    #   * 01 = Isochronous
    #   * 10 = Bulk
    #   * 11 = Interrupt
    # * Bits 2..7: are reserved. If Isochronous endpoint,
    # * Bits 3..2: Synchronisation Type (Iso Mode)
    #   * 00 = No Synchonisation
    #   * 01 = Asynchronous
    #   * 10 = Adaptive
    #   * 11 = Synchronous
    # * Bits 5..4: Usage Type (Iso Mode)
    #   * 00 = Data Endpoint
    #   * 01 = Feedback Endpoint
    #   * 10 = Explicit Feedback Data Endpoint
    #   * 11 = Reserved
    #
    # @return [Integer]
    def bmAttributes
      self[:bmAttributes]
    end

    # Maximum Packet Size this endpoint is capable of sending or receiving
    def wMaxPacketSize
      self[:wMaxPacketSize]
    end

    # Interval for polling endpoint data transfers. Value in frame counts.
    # Ignored for Bulk & Control Endpoints. Isochronous must equal 1 and field
    # may range from 1 to 255 for interrupt endpoints.
    #
    # The interval is respected by the kernel driver, so user mode processes
    # using libusb don't need to care about it.
    def bInterval
      self[:bInterval]
    end

    # For audio devices only: the rate at which synchronization feedback is provided.
    def bRefresh
      self[:bRefresh]
    end

    # For audio devices only: the address if the synch endpoint.
    def bSynchAddress
      self[:bSynchAddress]
    end

    # Extra descriptors.
    #
    # @return [String]
    def extra
      return if self[:extra].null?
      self[:extra].read_string(self[:extra_length])
    end

    def initialize(setting, *args)
      @setting = setting
      super(*args)
    end

    # @return [Setting] the setting this endpoint belongs to.
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
    def device() self.setting.interface.configuration.device end
    # The ConfigDescriptor the EndpointDescriptor belongs to.
    def configuration() self.setting.interface.configuration end
    # The Interface the EndpointDescriptor belongs to.
    def interface() self.setting.interface end

    def <=>(o)
      t = setting<=>o.setting
      t = bEndpointAddress<=>o.bEndpointAddress if t==0
      t
    end
  end


  # Class representing a libusb session.
  class Context
    # Initialize libusb context.
    def initialize
      m = FFI::MemoryPointer.new :pointer
      Call.libusb_init(m)
      @ctx = m.read_pointer
    end

    # Deinitialize libusb.
    #
    # Should be called after closing all open devices and before your application terminates.
    def exit
      Call.libusb_exit(@ctx)
    end

    # Set message verbosity.
    #
    # * Level 0: no messages ever printed by the library (default)
    # * Level 1: error messages are printed to stderr
    # * Level 2: warning and error messages are printed to stderr
    # * Level 3: informational messages are printed to stdout, warning and
    #   error messages are printed to stderr
    #
    # The default level is 0, which means no messages are ever printed. If you
    # choose to increase the message verbosity level, ensure that your
    # application does not close the stdout/stderr file descriptors.
    #
    # You are advised to set level 3. libusb is conservative with its message
    # logging and most of the time, will only log messages that explain error
    # conditions and other oddities. This will help you debug your software.
    #
    # If the LIBUSB_DEBUG environment variable was set when libusb was
    # initialized, this method does nothing: the message verbosity is
    # fixed to the value in the environment variable.
    #
    # If libusb was compiled without any message logging, this method
    # does nothing: you'll never get any messages.
    #
    # If libusb was compiled with verbose debug message logging, this
    # method does nothing: you'll always get messages from all levels.
    #
    # @param [Fixnum] level  debug level to set
    def debug=(level)
      Call.libusb_set_debug(@ctx, level)
    end

    def device_list
      pppDevs = FFI::MemoryPointer.new :pointer
      size = Call.libusb_get_device_list(@ctx, pppDevs)
      ppDevs = pppDevs.read_pointer
      pDevs = []
      size.times do |devi|
        pDev = ppDevs.get_pointer(devi*FFI.type_size(:pointer))
        pDevs << Device.new(self, pDev)
      end
      Call.libusb_free_device_list(ppDevs, 1)
      pDevs
    end
    private :device_list

    # Handle any pending events in blocking mode.
    #
    # This method must be called when libusb is running asynchronous transfers.
    # This gives libusb the opportunity to reap pending transfers,
    # invoke callbacks, etc.
    def handle_events
      res = Call.libusb_handle_events(@ctx)
      LIBUSB.raise_error res, "in libusb_handle_events" if res<0
    end

    # Obtain a list of devices currently attached to the USB system, optionally matching certain criteria.
    #
    # @param [Hash] filter_hash  A number of criteria can be defined in key-value pairs.
    #   Only devices that equal all given criterions will be returned. If a criterion is
    #   not specified or its value is +nil+, any device will match that criterion.
    #   The following criteria can be filtered:
    #   * <tt>:idVendor</tt>, <tt>:idProduct</tt> (+FixNum+) for matching vendor/product ID,
    #   * <tt>:bClass</tt>, <tt>:bSubClass</tt>, <tt>:bProtocol</tt> (+FixNum+) for the device type -
    #     Devices using CLASS_PER_INTERFACE will match, if any of the interfaces match.
    #   * <tt>:bcdUSB</tt>, <tt>:bcdDevice</tt>, <tt>:bMaxPacketSize0</tt> (+FixNum+) for the
    #     USB and device release numbers.
    #   Criteria can also specified as Array of several alternative values.
    #
    # @example
    #   # Return all devices of vendor 0x0ab1 where idProduct is 3 or 4:
    #   context.device :idVendor=>0x0ab1, :idProduct=>[0x0003, 0x0004]
    #
    # @return [Array<LIBUSB::Device>]
    def devices(filter_hash={})
      device_list.select do |dev|
        ( !filter_hash[:bClass] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceClass).&([filter_hash[:bClass]].flatten).any? :
                             [filter_hash[:bClass]].flatten.include?(dev.bDeviceClass))) &&
        ( !filter_hash[:bSubClass] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceSubClass).&([filter_hash[:bSubClass]].flatten).any? :
                             [filter_hash[:bSubClass]].flatten.include?(dev.bDeviceSubClass))) &&
        ( !filter_hash[:bProtocol] || (dev.bDeviceClass==CLASS_PER_INTERFACE ?
                             dev.settings.map(&:bInterfaceProtocol).&([filter_hash[:bProtocol]].flatten).any? :
                             [filter_hash[:bProtocol]].flatten.include?(dev.bDeviceProtocol))) &&
        ( !filter_hash[:bMaxPacketSize0] || [filter_hash[:bMaxPacketSize0]].flatten.include?(dev.bMaxPacketSize0) ) &&
        ( !filter_hash[:idVendor] || [filter_hash[:idVendor]].flatten.include?(dev.idVendor) ) &&
        ( !filter_hash[:idProduct] || [filter_hash[:idProduct]].flatten.include?(dev.idProduct) ) &&
        ( !filter_hash[:bcdUSB] || [filter_hash[:bcdUSB]].flatten.include?(dev.bcdUSB) ) &&
        ( !filter_hash[:bcdDevice] || [filter_hash[:bcdDevice]].flatten.include?(dev.bcdDevice) )
      end
    end
  end

  # Class representing a USB device detected on the system.
  #
  # Devices of the system can be obtained with {Context#devices} .
  class Device
    include Comparable

    # @return [Context] the context this device belongs to.
    attr_reader :context

    def initialize context, pDev
      @context = context
      def pDev.unref_device(id)
        Call.libusb_unref_device(self)
      end
      ObjectSpace.define_finalizer(self, pDev.method(:unref_device))
      Call.libusb_ref_device(pDev)
      @pDev = pDev

      @pDevDesc = DeviceDescriptor.new
      res = Call.libusb_get_device_descriptor(@pDev, @pDevDesc)
      LIBUSB.raise_error res, "in libusb_get_device_descriptor" if res!=0
    end

    # Open the device and obtain a device handle.
    #
    # A handle allows you to perform I/O on the device in question.
    # This is a non-blocking function; no requests are sent over the bus.
    #
    # If called with a block, the handle is passed to the block
    # and is closed when the block has finished.
    #
    # You need proper access permissions on:
    # * Linux: <tt>/dev/bus/usb/<bus>/<dev></tt>
    #
    # @return [DevHandle] Handle to the device.
    def open
      ppHandle = FFI::MemoryPointer.new :pointer
      res = Call.libusb_open(@pDev, ppHandle)
      LIBUSB.raise_error res, "in libusb_open" if res!=0
      handle = DevHandle.new self, ppHandle.read_pointer
      return handle unless block_given?
      begin
        yield handle
      ensure
        handle.close
      end
    end

    # Open the device and claim an interface.
    #
    # This is a convenience method to {Device#open} and {DevHandle#claim_interface}.
    # Must be called with a block. When the block has finished, the interface
    # will be released and the device will be closed.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you wish to claim
    def open_interface(interface)
      open do |dev|
        dev.claim_interface(interface) do
          yield dev
        end
      end
    end

    # Get the number of the bus that a device is connected to.
    def bus_number
      Call.libusb_get_bus_number(@pDev)
    end

    # Get the address of the device on the bus it is connected to.
    def device_address
      Call.libusb_get_device_address(@pDev)
    end

    # Convenience function to retrieve the wMaxPacketSize value for a
    # particular endpoint in the active device configuration.
    #
    # @param [Endpoint, Fixnum] endpoint  (address of) the endpoint in question
    # @return [Fixnum]  the wMaxPacketSize value
    def max_packet_size(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_get_max_packet_size(@pDev, endpoint)
      LIBUSB.raise_error res, "in libusb_get_max_packet_size" unless res>=0
      res
    end

    # Calculate the maximum packet size which a specific endpoint is capable is
    # sending or receiving in the duration of 1 microframe.
    #
    # Only the active configution is examined. The calculation is based on the
    # wMaxPacketSize field in the endpoint descriptor as described in section 9.6.6
    # in the USB 2.0 specifications.
    #
    # If acting on an isochronous or interrupt endpoint, this function will
    # multiply the value found in bits 0:10 by the number of transactions per
    # microframe (determined by bits 11:12). Otherwise, this function just returns
    # the numeric value found in bits 0:10.
    #
    # This function is useful for setting up isochronous transfers, for example
    # you might use the return value from this function to call
    # IsoPacket#alloc_buffer in order to set the length field
    # of an isochronous packet in a transfer.
    #
    # @param [Endpoint, Fixnum] endpoint  (address of) the endpoint in question
    # @return [Fixnum] the maximum packet size which can be sent/received on this endpoint
    def max_iso_packet_size(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_get_max_iso_packet_size(@pDev, endpoint)
      LIBUSB.raise_error res, "in libusb_get_max_iso_packet_size" unless res>=0
      res
    end

    # Obtain a config descriptor of the device.
    #
    # @param [Fixnum] index  number of the config descriptor
    # @return Configuration
    def config_descriptor(index)
      ppConfig = FFI::MemoryPointer.new :pointer
      res = Call.libusb_get_config_descriptor(@pDev, index, ppConfig)
      LIBUSB.raise_error res, "in libusb_get_config_descriptor" if res!=0
      pConfig = ppConfig.read_pointer
      config = Configuration.new(self, pConfig)
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
        devclass = self.settings.map {|i|
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

    # Return manufacturer of the device
    # @return String
    def manufacturer
      return @manufacturer if defined? @manufacturer
      @manufacturer = try_string_descriptor_ascii(self.iManufacturer)
      @manufacturer.strip! if @manufacturer
      @manufacturer
    end

    # Return product name of the device.
    # @return String
    def product
      return @product if defined? @product
      @product = try_string_descriptor_ascii(self.iProduct)
      @product.strip! if @product
      @product
    end

    # Return serial number of the device.
    # @return String
    def serial_number
      return @serial_number if defined? @serial_number
      @serial_number = try_string_descriptor_ascii(self.iSerialNumber)
      @serial_number.strip! if @serial_number
      @serial_number
    end

    # Return configurations of the device.
    # @return [Array<Configuration>]
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

    # Return all interfaces of the device.
    # @return [Array<Interface>]
    def interfaces() self.configurations.map {|d| d.interfaces }.flatten end
    # Return all interface decriptions of the device.
    # @return [Array<Setting>]
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    # Return all endpoints of all interfaces of the device.
    # @return [Array<Endpoint>]
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def <=>(o)
      t = bus_number<=>o.bus_number
      t = device_address<=>o.device_address if t==0
      t
    end
  end

  # Class representing a handle on a USB device.
  #
  # A device handle is used to perform I/O and other operations. When finished
  # with a device handle, you should call DevHandle#close .
  class DevHandle
    # @private
    attr_reader :pHandle
    # @return [Device] the device this handle belongs to.
    attr_reader :device

    def initialize device, pHandle
      @device = device
      @pHandle = pHandle
      @bulk_transfer = @control_transfer = @interrupt_transfer = nil
    end

    # Close a device handle.
    #
    # Should be called on all open handles before your application exits.
    #
    # Internally, this function destroys the reference that was added by {Device#open}
    # on the given device.
    #
    # This is a non-blocking function; no requests are sent over the bus.
    def close
      Call.libusb_close(@pHandle)
    end

    def string_descriptor_ascii(index)
      pString = FFI::MemoryPointer.new 0x100
      res = Call.libusb_get_string_descriptor_ascii(@pHandle, index, pString, pString.size)
      LIBUSB.raise_error res, "in libusb_get_string_descriptor_ascii" unless res>=0
      pString.read_string(res)
    end

    # Claim an interface on a given device handle.
    #
    # You must claim the interface you wish to use before you can perform I/O on any
    # of its endpoints.
    #
    # It is legal to attempt to claim an already-claimed interface, in which case
    # libusb just returns without doing anything.
    #
    # Claiming of interfaces is a purely logical operation; it does not cause any
    # requests to be sent over the bus. Interface claiming is used to instruct the
    # underlying operating system that your application wishes to take ownership of
    # the interface.
    #
    # This is a non-blocking function.
    #
    # If called with a block, the device handle is passed through to the block
    # and the interface is released when the block has finished.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you wish to claim
    def claim_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_claim_interface(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_claim_interface" if res!=0
      return self unless block_given?
      begin
        yield self
      ensure
        release_interface(interface)
      end
    end

    # Release an interface previously claimed with {DevHandle#claim_interface}.
    #
    # You should release all claimed interfaces before closing a device handle.
    #
    # This is a blocking function. A SET_INTERFACE control request will be sent to the
    # device, resetting interface state to the first alternate setting.
    #
    # @param [Interface, Fixnum] interface  the interface or it's bInterfaceNumber you
    #   claimed previously
    def release_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_release_interface(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_release_interface" if res!=0
    end

    # Set the active configuration for a device.
    #
    # The operating system may or may not have already set an active configuration on
    # the device. It is up to your application to ensure the correct configuration is
    # selected before you attempt to claim interfaces and perform other operations.
    #
    # If you call this function on a device already configured with the selected
    # configuration, then this function will act as a lightweight device reset: it
    # will issue a SET_CONFIGURATION request using the current configuration, causing
    # most USB-related device state to be reset (altsetting reset to zero, endpoint
    # halts cleared, toggles reset).
    #
    # You cannot change/reset configuration if your application has claimed interfaces -
    # you should free them with {DevHandle#release_interface} first. You cannot
    # change/reset configuration if other applications or drivers have claimed
    # interfaces.
    #
    # A configuration value of +nil+ will put the device in unconfigured state. The USB
    # specifications state that a configuration value of 0 does this, however buggy
    # devices exist which actually have a configuration 0.
    #
    # You should always use this function rather than formulating your own
    # SET_CONFIGURATION control request. This is because the underlying operating
    # system needs to know when such changes happen.
    #
    # This is a blocking function.
    #
    # @param [Configuration, Fixnum] configuration   the configuration or it's
    #   bConfigurationValue you wish to activate, or +nil+ if you wish to put
    #   the device in unconfigured state
    def set_configuration(configuration)
      configuration = configuration.bConfigurationValue if configuration.respond_to? :bConfigurationValue
      res = Call.libusb_set_configuration(@pHandle, configuration || -1)
      LIBUSB.raise_error res, "in libusb_set_configuration" if res!=0
    end
    alias configuration= set_configuration

    # Activate an alternate setting for an interface.
    #
    # The interface must have been previously claimed with {DevHandle#claim_interface}.
    #
    # You should always use this function rather than formulating your own
    # SET_INTERFACE control request. This is because the underlying operating system
    # needs to know when such changes happen.
    #
    # This is a blocking function.
    #
    # @param [Setting, Fixnum] setting_or_interface_number  the alternate setting
    #   to activate or the bInterfaceNumber of the previously-claimed interface
    # @param [Fixnum, nil] alternate_setting  the bAlternateSetting of the alternate setting to activate
    #   (only if first param is a Fixnum)
    def set_interface_alt_setting(setting_or_interface_number, alternate_setting=nil)
      alternate_setting ||= setting_or_interface_number.bAlternateSetting if setting_or_interface_number.respond_to? :bAlternateSetting
      setting_or_interface_number = setting_or_interface_number.bInterfaceNumber if setting_or_interface_number.respond_to? :bInterfaceNumber
      res = Call.libusb_set_interface_alt_setting(@pHandle, setting_or_interface_number, alternate_setting)
      LIBUSB.raise_error res, "in libusb_set_interface_alt_setting" if res!=0
    end

    # Clear the halt/stall condition for an endpoint.
    #
    # Endpoints with halt status are unable to receive or transmit
    # data until the halt condition is stalled.
    #
    # You should cancel all pending transfers before attempting to
    # clear the halt condition.
    #
    # This is a blocking function.
    #
    # @param [Endpoint, Fixnum] endpoint  the endpoint in question or it's bEndpointAddress
    def clear_halt(endpoint)
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      res = Call.libusb_clear_halt(@pHandle, endpoint)
      LIBUSB.raise_error res, "in libusb_clear_halt" if res!=0
    end

    # Perform a USB port reset to reinitialize a device.
    #
    # The system will attempt to restore the previous configuration and
    # alternate settings after the reset has completed.
    #
    # If the reset fails, the descriptors change, or the previous
    # state cannot be restored, the device will appear to be disconnected
    # and reconnected. This means that the device handle is no longer
    # valid (you should close it) and rediscover the device. A Exception
    # of LIBUSB::ERROR_NOT_FOUND indicates when this is the case.
    #
    # This is a blocking function which usually incurs a noticeable delay.
    def reset_device
      res = Call.libusb_reset_device(@pHandle)
      LIBUSB.raise_error res, "in libusb_reset_device" if res!=0
    end

    # Determine if a kernel driver is active on an interface.
    #
    # If a kernel driver is active, you cannot claim the interface,
    # and libusb will be unable to perform I/O.
    #
    # @param [Interface, Fixnum] interface   the interface to check or it's bInterfaceNumber
    # @return [Boolean]
    def kernel_driver_active?(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_kernel_driver_active(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_kernel_driver_active" unless res>=0
      return res==1
    end

    # Detach a kernel driver from an interface.
    #
    # If successful, you will then be able to claim the interface and perform I/O.
    #
    # @param [Interface, Fixnum] interface    the interface to detach the driver
    #   from or it's bInterfaceNumber
    def detach_kernel_driver(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_detach_kernel_driver(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_detach_kernel_driver" if res!=0
    end

    # Re-attach an interface's kernel driver, which was previously detached
    # using {DevHandle#detach_kernel_driver}.
    #
    # @param [Interface, Fixnum] interface    the interface to attach the driver to
    def attach_kernel_driver(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      res = Call.libusb_attach_kernel_driver(@pHandle, interface)
      LIBUSB.raise_error res, "in libusb_attach_kernel_driver" if res!=0
    end


    # Perform a USB bulk transfer.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For bulk reads, the +:dataIn+ param indicates the maximum length of data you are
    # expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should also check the returned number of bytes for bulk writes. Not all of the
    # data may have been written.
    #
    # Also check transferred bytes when dealing with a timeout error code. libusb may have
    # to split your transfer into a number of chunks to satisfy underlying O/S
    # requirements, meaning that the timeout may expire after the first few chunks
    # have completed. libusb is careful not to lose any data that may have been
    # transferred; do not assume that timeout conditions indicate a complete lack of
    # I/O.
    #
    # @param [Endpoint, Fixnum] :endpoint  the (address of a) valid endpoint to communicate with
    # @param [String] :dataOut  the data to send with an outgoing transfer
    # @param [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    # @param [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent for an outgoing transfer
    # @return [String] Received data for an ingoing transfer
    def bulk_transfer(args={})
      timeout = args.delete(:timeout) || 1000
      endpoint = args.delete(:endpoint) || raise(ArgumentError, "no endpoint given")
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || raise(ArgumentError, "no :dataIn given for bulk read")
      else
        dataOut = args.delete(:dataOut) || raise(ArgumentError, "no :dataOut given for bulk write")
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @bulk_transfer ||= BulkTransfer.new :dev_handle => self
      tr = @bulk_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      tr.submit_and_wait!

      if dataOut
        tr.actual_length
      else
        tr.actual_buffer
      end
    end

    # Perform a USB interrupt transfer.
    #
    # The direction of the transfer is inferred from the direction bits of the
    # endpoint address.
    #
    # For interrupt reads, the +:dataIn+ param indicates the maximum length of data you
    # are expecting to receive. If less data arrives than expected, this function will
    # return that data.
    #
    # You should also check the returned number of bytes for interrupt writes. Not all of
    # the data may have been written.
    #
    # Also check transferred when dealing with a timeout error code. libusb may have
    # to split your transfer into a number of chunks to satisfy underlying O/S
    # requirements, meaning that the timeout may expire after the first few chunks
    # have completed. libusb is careful not to lose any data that may have been
    # transferred; do not assume that timeout conditions indicate a complete lack of
    # I/O.
    #
    # The default endpoint bInterval value is used as the polling interval.
    #
    # @param [Endpoint, Fixnum] :endpoint  the (address of a) valid endpoint to communicate with
    # @param [String] :dataOut  the data to send with an outgoing transfer
    # @param [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    # @param [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent for an outgoing transfer
    # @return [String] Received data for an ingoing transfer
    def interrupt_transfer(args={})
      timeout = args.delete(:timeout) || 1000
      endpoint = args.delete(:endpoint) || raise(ArgumentError, "no endpoint given")
      endpoint = endpoint.bEndpointAddress if endpoint.respond_to? :bEndpointAddress
      if endpoint&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || raise(ArgumentError, "no :dataIn given for interrupt read")
      else
        dataOut = args.delete(:dataOut) || raise(ArgumentError, "no :dataOut given for interrupt write")
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @interrupt_transfer ||= InterruptTransfer.new :dev_handle => self
      tr = @interrupt_transfer
      tr.endpoint = endpoint
      tr.timeout = timeout
      if dataOut
        tr.buffer = dataOut
      else
        tr.alloc_buffer(dataIn)
      end

      tr.submit_and_wait!

      if dataOut
        tr.actual_length
      else
        tr.actual_buffer
      end
    end

    # Perform a USB control transfer.
    #
    # The direction of the transfer is inferred from the +:bmRequestType+ field of the
    # setup packet.
    #
    # @param [Fixnum] :bmRequestType   the request type field for the setup packet
    # @param [Fixnum] :bRequest  the request field for the setup packet
    # @param [Fixnum] :wValue  the value field for the setup packet
    # @param [Fixnum] :wIndex  the index field for the setup packet
    # @param [String] :dataOut  the data to send with an outgoing transfer, it
    #   is appended to the setup packet
    # @param [Fixnum] :dataIn   the number of bytes expected to receive with an ingoing transfer
    #   (excluding setup packet)
    # @param [Fixnum] :timeout   timeout (in millseconds) that this function should wait before giving
    #   up due to no response being received. For an unlimited timeout, use value 0. Defaults to 1000 ms.
    #
    # @return [Fixnum] Number of bytes sent (excluding setup packet) for outgoing transfer
    # @return [String] Received data (without setup packet) for ingoing transfer
    def control_transfer(args={})
      bmRequestType = args.delete(:bmRequestType) || raise(ArgumentError, "param :bmRequestType not given")
      bRequest = args.delete(:bRequest) || raise(ArgumentError, "param :bRequest not given")
      wValue = args.delete(:wValue) || raise(ArgumentError, "param :wValue not given")
      wIndex = args.delete(:wIndex) || raise(ArgumentError, "param :wIndex not given")
      timeout = args.delete(:timeout) || 1000
      if bmRequestType&ENDPOINT_IN != 0
        dataIn = args.delete(:dataIn) || 0
        dataOut = ''
      else
        dataOut = args.delete(:dataOut) || ''
      end
      raise ArgumentError, "invalid params #{args.inspect}" unless args.empty?

      # reuse transfer struct to speed up transfer
      @control_transfer ||= ControlTransfer.new :dev_handle => self
      tr = @control_transfer
      tr.timeout = timeout
      if dataIn
        setup_data = [bmRequestType, bRequest, wValue, wIndex, dataIn].pack('CCvvv')
        tr.alloc_buffer( dataIn + CONTROL_SETUP_SIZE, setup_data )
      else
        tr.buffer = [bmRequestType, bRequest, wValue, wIndex, dataOut.bytesize, dataOut].pack('CCvvva*')
      end

      tr.submit_and_wait!

      if dataIn
        tr.actual_buffer(CONTROL_SETUP_SIZE)
      else
        tr.actual_length
      end
    end
  end

end
