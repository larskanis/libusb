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
  # C level interface - for internal use only
  #
  # All enum codes are available as constants in {LIBUSB} namespace.
  module Call
    extend FFI::Library

    ext = FFI::Platform.windows? ? 'dll' : 'so'
    bundled_dll = File.expand_path("../../libusb-1.0.#{ext}", __FILE__)
    ffi_lib(['libusb-1.0', bundled_dll])

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
      :TRANSFER_ADD_ZERO_PACKET, 1 << 3,
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

    Speeds = enum :libusb_speed, [
      :SPEED_UNKNOWN, 0,
      :SPEED_LOW, 1,
      :SPEED_FULL, 2,
      :SPEED_HIGH, 3,
      :SPEED_SUPER, 4,
    ]

    Capabilities = enum :libusb_capability, [
      :CAP_HAS_CAPABILITY, 0,
    ]

    typedef :pointer, :libusb_context
    typedef :pointer, :libusb_device_handle

    def self.try_attach_function(method, *args)
      if ffi_libraries.find{|lib| lib.find_function(method) }
        attach_function method, *args
      end
    end

    try_attach_function 'libusb_get_version', [], :pointer

    attach_function 'libusb_init', [ :pointer ], :int
    attach_function 'libusb_exit', [ :pointer ], :void
    attach_function 'libusb_set_debug', [:pointer, :int], :void
    try_attach_function 'libusb_has_capability', [:libusb_capability], :int

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
    try_attach_function 'libusb_get_port_number', [:pointer], :uint8
    try_attach_function 'libusb_get_parent', [:pointer], :pointer
    try_attach_function 'libusb_get_port_path', [:pointer, :pointer, :pointer, :uint8], :uint8
    attach_function 'libusb_get_device_address', [:pointer], :uint8
    try_attach_function 'libusb_get_device_speed', [:pointer], :libusb_speed
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
    try_attach_function 'libusb_handle_events_completed', [:libusb_context, :pointer], :int, :blocking=>true
    attach_function 'libusb_handle_events_timeout', [:libusb_context, :pointer], :int, :blocking=>true
    try_attach_function 'libusb_handle_events_timeout_completed', [:libusb_context, :pointer, :pointer], :int, :blocking=>true

    callback :libusb_pollfd_added_cb, [:int, :short, :pointer], :void
    callback :libusb_pollfd_removed_cb, [:int, :pointer], :void

    attach_function 'libusb_get_pollfds', [:libusb_context], :pointer
    attach_function 'libusb_get_next_timeout', [:libusb_context, :pointer], :int
    attach_function 'libusb_set_pollfd_notifiers', [:libusb_context, :libusb_pollfd_added_cb, :libusb_pollfd_removed_cb, :pointer], :void

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

    class Timeval < FFI::Struct
      layout :tv_sec,  :long,
        :tv_usec, :long

      # set timeval to the number of milliseconds
      # @param [Fixnum] value
      def in_ms=(value)
        self[:tv_sec], self[:tv_usec] = (value*1000).divmod(1000000)
      end

      # get the number of milliseconds in timeval
      # @return [Fixnum]
      def in_ms
        self[:tv_sec]*1000 + self[:tv_usec]/1000
      end

      # set timeval to the number of seconds
      # @param [Numeric] value
      def in_s=(value)
        self[:tv_sec], self[:tv_usec] = (value*1000000).divmod(1000000)
      end

      # get the number of seconds in timeval
      # @return [Float]
      def in_s
        self[:tv_sec] + self[:tv_usec]/1000000.0
      end
    end

    class Pollfd < FFI::Struct
      layout :fd,  :int,
          :events, :short
    end
  end
end
