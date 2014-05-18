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

require 'libusb/call'

module LIBUSB
  Call::ClassCodes.to_h.each{|k,v| const_set(k,v) }
  Call::TransferTypes.to_h.each{|k,v| const_set(k,v) }
  Call::StandardRequests.to_h.each{|k,v| const_set(k,v) }
  Call::RequestTypes.to_h.each{|k,v| const_set(k,v) }
  Call::DescriptorTypes.to_h.each{|k,v| const_set(k,v) }
  Call::EndpointDirections.to_h.each{|k,v| const_set(k,v) }
  Call::RequestRecipients.to_h.each{|k,v| const_set(k,v) }
  Call::IsoSyncTypes.to_h.each{|k,v| const_set(k,v) }
  Call::Speeds.to_h.each{|k,v| const_set(k,v) }
  Call::Capabilities.to_h.each{|k,v| const_set(k,v) }
  Call::SupportedSpeeds.to_h.each{|k,v| const_set(k,v) }
  Call::Usb20ExtensionAttributes.to_h.each{|k,v| const_set(k,v) }
  Call::SsUsbDeviceCapabilityAttributes.to_h.each{|k,v| const_set(k,v) }
  Call::BosTypes.to_h.each{|k,v| const_set(k,v) }
  Call::HotplugEvents.to_h.each{|k,v| const_set(k,v) }
  Call::HotplugFlags.to_h.each{|k,v| const_set(k,v) }

  # Base class of libusb errors
  class Error < RuntimeError
    # The data already transferred before the exception was raised
    # @return [Fixnum] Number of bytes sent for an outgoing transfer
    # @return [String] Received data for an ingoing transfer
    attr_reader :transferred

    def initialize(msg=nil, transferred=nil)
      super(msg)
      @transferred = transferred
    end
  end

  # @private
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

  POLLIN = 1
  POLLOUT = 4

  # Wildcard matching for hotplug events.
  HOTPLUG_MATCH_ANY = -1


  # http://www.usb.org/developers/defined_class
  # @private
  CLASS_CODES = [
    [0x01, nil, nil, "Audio"],
    [0x02, nil, nil, "Comm"],
    [0x03, nil, nil, "HID"],
    [0x05, nil, nil, "Physical"],
    [0x06, 0x01, 0x01, "StillImaging"],
    [0x06, nil, nil, "Image"],
    [0x07, nil, nil, "Printer"],
    [0x08, 0x01, nil, "MassStorage RBC Bulk-Only"],
    [0x08, 0x02, 0x50, "MassStorage ATAPI Bulk-Only"],
    [0x08, 0x03, 0x50, "MassStorage QIC-157 Bulk-Only"],
    [0x08, 0x04, nil, "MassStorage UFI"],
    [0x08, 0x05, 0x50, "MassStorage SFF-8070i Bulk-Only"],
    [0x08, 0x06, 0x50, "MassStorage SCSI Bulk-Only"],
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
  # @private
  CLASS_CODES_HASH1 = {}
  # @private
  CLASS_CODES_HASH2 = {}
  # @private
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
      "Unknown(%02x,%02x,%02x)" % [base_class, sub_class, protocol]
    end
  end
end
