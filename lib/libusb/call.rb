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

    root_path = File.expand_path("../../..", __FILE__)
    ext = FFI::Platform::LIBSUFFIX
    prefix = FFI::Platform::LIBPREFIX.empty? ? 'lib' : FFI::Platform::LIBPREFIX
    bundled_dll = File.join(root_path, "lib/#{prefix}usb-1.0.#{ext}")
    bundled_dll_cygwin = File.join(root_path, "bin/#{prefix}usb-1.0.#{ext}")
    ffi_lib(["#{prefix}usb-1.0", bundled_dll, bundled_dll_cygwin])

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

    # Values for {Endpoint#transfer_type}.
    TransferTypes = enum :libusb_transfer_type, [
      # Control endpoint
      :TRANSFER_TYPE_CONTROL, 0,
      # Isochronous endpoint
      :TRANSFER_TYPE_ISOCHRONOUS, 1,
      # Bulk endpoint
      :TRANSFER_TYPE_BULK, 2,
      # Interrupt endpoint
      :TRANSFER_TYPE_INTERRUPT, 3,
      # Stream endpoint
      :TRANSFER_TYPE_BULK_STREAM, 4,
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
      # Device descriptor. See {Device}
      :DT_DEVICE, 0x01,
      # Configuration descriptor. See {Configuration}
      :DT_CONFIG, 0x02,
      # String descriptor
      :DT_STRING, 0x03,
      # Interface descriptor. See {Interface}
      :DT_INTERFACE, 0x04,
      # Endpoint descriptor. See {Endpoint}
      :DT_ENDPOINT, 0x05,
      # BOS descriptor
      :DT_BOS, 0x0f,
      # Device Capability descriptor
      :DT_DEVICE_CAPABILITY, 0x10,
      # HID descriptor
      :DT_HID, 0x21,
      # HID report descriptor
      :DT_REPORT, 0x22,
      # Physical descriptor
      :DT_PHYSICAL, 0x23,
      # Hub descriptor
      :DT_HUB, 0x29,
      # SuperSpeed Hub descriptor
      :DT_SUPERSPEED_HUB, 0x2a,
      # SuperSpeed Endpoint Companion descriptor
      :DT_SS_ENDPOINT_COMPANION, 0x30,
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

    # Supported speeds (wSpeedSupported) bitfield. Indicates what
    # speeds the device supports.
    SupportedSpeeds = enum :libusb_supported_speed, [
      # Low speed operation supported (1.5MBit/s).
      :LOW_SPEED_OPERATION, 1,
      # Full speed operation supported (12MBit/s).
      :FULL_SPEED_OPERATION, 2,
      # High speed operation supported (480MBit/s).
      :HIGH_SPEED_OPERATION, 4,
      # Superspeed operation supported (5000MBit/s).
      :SUPER_SPEED_OPERATION, 8,
    ]

    Capabilities = enum :libusb_capability, [
      :CAP_HAS_CAPABILITY, 0x0000,
      # Hotplug support is available on this platform.
      :CAP_HAS_HOTPLUG, 0x0001,
      # The library can access HID devices without requiring user intervention.
      # Note that before being able to actually access an HID device, you may
      # still have to call additional libusb functions such as
      # {DevHandle#detach_kernel_driver}.
      :CAP_HAS_HID_ACCESS, 0x0100,
      # The library supports detaching of the default USB driver, using
      # {DevHandle#detach_kernel_driver}, if one is set by the OS kernel.
      :CAP_SUPPORTS_DETACH_KERNEL_DRIVER, 0x0101,
    ]

    # Masks for the bits of the
    # {Bos::Usb20Extension#bmAttributes} field
    # of the USB 2.0 Extension descriptor.
    Usb20ExtensionAttributes = enum :libusb_usb_2_0_extension_attributes, [
      # Supports Link Power Management (LPM)
      :BM_LPM_SUPPORT, 2,
    ]

    # Masks for the bits of the
    # {Bos::SsUsbDeviceCapability#bmAttributes} field
    # field of the SuperSpeed USB Device Capability descriptor.
    SsUsbDeviceCapabilityAttributes = enum :libusb_ss_usb_device_capability_attributes, [
      # Supports Latency Tolerance Messages (LTM)
      :BM_LTM_SUPPORT, 2,
    ]

    # USB capability types
    #
    # @see Bos::DeviceCapability
    BosTypes = enum :libusb_bos_type, [
      # Wireless USB device capability
      :BT_WIRELESS_USB_DEVICE_CAPABILITY, 1,
      # USB 2.0 extensions
      :BT_USB_2_0_EXTENSION, 2,
      # SuperSpeed USB device capability
      :BT_SS_USB_DEVICE_CAPABILITY, 3,
      # Container ID type
      :BT_CONTAINER_ID, 4,
    ]

    # Since libusb version 1.0.16.
    #
    # Hotplug events
    HotplugEvents = enum :libusb_hotplug_event, [
      # A device has been plugged in and is ready to use.
      :HOTPLUG_EVENT_DEVICE_ARRIVED, 0x01,

      # A device has left and is no longer available.
      # It is the user's responsibility to call libusb_close on any handle associated with a disconnected device.
      # It is safe to call libusb_get_device_descriptor on a device that has left.
      :HOTPLUG_EVENT_DEVICE_LEFT, 0x02,
    ]

    # Since libusb version 1.0.16.
    #
    # Flags for hotplug events */
    HotplugFlags = enum :libusb_hotplug_flag, [
      # Arm the callback and fire it for all matching currently attached devices.
      :HOTPLUG_ENUMERATE, 1,
    ]

    typedef :pointer, :libusb_context
    typedef :pointer, :libusb_device
    typedef :pointer, :libusb_device_handle
    typedef :pointer, :libusb_transfer
    typedef :int, :libusb_hotplug_callback_handle

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

    attach_function 'libusb_get_device_list', [:pointer, :pointer], :ssize_t
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
    try_attach_function 'libusb_get_port_numbers', [:pointer, :pointer, :uint8], :uint8
    attach_function 'libusb_get_device_address', [:pointer], :uint8
    try_attach_function 'libusb_get_device_speed', [:pointer], :libusb_speed
    attach_function 'libusb_get_max_packet_size', [:pointer, :uint8], :int
    attach_function 'libusb_get_max_iso_packet_size', [:pointer, :uint8], :int

    try_attach_function 'libusb_get_ss_endpoint_companion_descriptor', [:pointer, :pointer, :pointer], :int
    try_attach_function 'libusb_free_ss_endpoint_companion_descriptor', [:pointer], :void

    try_attach_function 'libusb_get_bos_descriptor', [:libusb_device_handle, :pointer], :int, :blocking=>true
    try_attach_function 'libusb_free_bos_descriptor', [:pointer], :void
    try_attach_function 'libusb_get_usb_2_0_extension_descriptor', [:libusb_context, :pointer, :pointer], :int
    try_attach_function 'libusb_free_usb_2_0_extension_descriptor', [:pointer], :void
    try_attach_function 'libusb_get_ss_usb_device_capability_descriptor', [:libusb_context, :pointer, :pointer], :int
    try_attach_function 'libusb_free_ss_usb_device_capability_descriptor', [:pointer], :void
    try_attach_function 'libusb_get_container_id_descriptor', [:libusb_context, :pointer, :pointer], :int
    try_attach_function 'libusb_free_container_id_descriptor', [:pointer], :void

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
    try_attach_function 'libusb_alloc_streams', [:libusb_device_handle, :uint32, :pointer, :int], :int
    try_attach_function 'libusb_free_streams', [:libusb_device_handle, :pointer, :int], :int

    attach_function 'libusb_kernel_driver_active', [:libusb_device_handle, :int], :int
    attach_function 'libusb_detach_kernel_driver', [:libusb_device_handle, :int], :int
    attach_function 'libusb_attach_kernel_driver', [:libusb_device_handle, :int], :int
    try_attach_function 'libusb_set_auto_detach_kernel_driver', [:libusb_device_handle, :int], :int

    attach_function 'libusb_get_string_descriptor_ascii', [:pointer, :uint8, :pointer, :int], :int

    attach_function 'libusb_alloc_transfer', [:int], :pointer
    attach_function 'libusb_submit_transfer', [:pointer], :int
    attach_function 'libusb_cancel_transfer', [:pointer], :int
    attach_function 'libusb_free_transfer', [:pointer], :void
    try_attach_function 'libusb_transfer_set_stream_id', [:libusb_transfer, :uint32], :void
    try_attach_function 'libusb_transfer_get_stream_id', [:libusb_transfer], :uint32

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

    callback :libusb_hotplug_callback_fn, [:libusb_context, :libusb_device, :libusb_hotplug_event, :pointer], :int
    try_attach_function 'libusb_hotplug_register_callback', [
        :libusb_context, :libusb_hotplug_event, :libusb_hotplug_flag,
        :int, :int, :int, :libusb_hotplug_callback_fn,
        :pointer, :pointer], :int
    try_attach_function 'libusb_hotplug_deregister_callback', [:libusb_context, :libusb_hotplug_callback_handle], :void

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
