#!/usr/bin/env ruby
#   Ruby bindings to libusb.
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License as
#   published by the Free Software Foundation; version 2 of the License.
#
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#   General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place - Suite 330, Boston,
#   MA 02111-1307, USA.
#
#   This file is for compatibility with ruby-usb and libusb-0.1.
#
#   Please visit the project website at http://github.com/larskanis/libusb
#   for support.

require 'libusb'
require 'forwardable'

# Compatibility layer for ruby-usb[http://www.a-k-r.org/ruby-usb/] (API based on libusb-0.1)
#
# This module provides some limited compatibility to ruby-usb.
#
# Usage example:
#   begin
#     require 'usb'
#   rescue LoadError
#     require 'libusb/compat'
#   end
#   p USB.devices => [#<USB::Device ...>]
#
# Known issues:
# * Exceptions are different between ruby-usb and libusb and don't get converted
# * libusb-1.0 doesn't explicitly manage USB-buses, so only one Bus is used currently
module USB
  DefaultContext = LIBUSB::Context.new

  USB_CLASS_PER_INTERFACE = LIBUSB::CLASS_PER_INTERFACE
  USB_CLASS_AUDIO = LIBUSB::CLASS_AUDIO
  USB_CLASS_COMM = LIBUSB::CLASS_COMM
  USB_CLASS_HID = LIBUSB::CLASS_HID
  USB_CLASS_PRINTER = LIBUSB::CLASS_PRINTER
  USB_CLASS_PTP = LIBUSB::CLASS_PTP
  USB_CLASS_MASS_STORAGE = LIBUSB::CLASS_MASS_STORAGE
  USB_CLASS_HUB = LIBUSB::CLASS_HUB
  USB_CLASS_DATA = LIBUSB::CLASS_DATA
  USB_CLASS_VENDOR_SPEC = LIBUSB::CLASS_VENDOR_SPEC

  USB_DT_DEVICE = LIBUSB::DT_DEVICE
  USB_DT_CONFIG = LIBUSB::DT_CONFIG
  USB_DT_STRING = LIBUSB::DT_STRING
  USB_DT_INTERFACE = LIBUSB::DT_INTERFACE
  USB_DT_ENDPOINT = LIBUSB::DT_ENDPOINT
  USB_DT_HID = LIBUSB::DT_HID
  USB_DT_REPORT = LIBUSB::DT_REPORT
  USB_DT_PHYSICAL = LIBUSB::DT_PHYSICAL
  USB_DT_HUB = LIBUSB::DT_HUB
  USB_DT_DEVICE_SIZE = LIBUSB::DT_DEVICE_SIZE
  USB_DT_CONFIG_SIZE = LIBUSB::DT_CONFIG_SIZE
  USB_DT_INTERFACE_SIZE = LIBUSB::DT_INTERFACE_SIZE
  USB_DT_ENDPOINT_SIZE = LIBUSB::DT_ENDPOINT_SIZE
  USB_DT_ENDPOINT_AUDIO_SIZE = LIBUSB::DT_ENDPOINT_AUDIO_SIZE
  USB_DT_HUB_NONVAR_SIZE = LIBUSB::DT_HUB_NONVAR_SIZE

  USB_ENDPOINT_ADDRESS_MASK = LIBUSB::ENDPOINT_ADDRESS_MASK
  USB_ENDPOINT_DIR_MASK = LIBUSB::ENDPOINT_DIR_MASK
  USB_ENDPOINT_IN = LIBUSB::ENDPOINT_IN
  USB_ENDPOINT_OUT = LIBUSB::ENDPOINT_OUT

  USB_ENDPOINT_TYPE_MASK = LIBUSB::TRANSFER_TYPE_MASK
  USB_ENDPOINT_TYPE_CONTROL = LIBUSB::TRANSFER_TYPE_CONTROL
  USB_ENDPOINT_TYPE_ISOCHRONOUS = LIBUSB::TRANSFER_TYPE_ISOCHRONOUS
  USB_ENDPOINT_TYPE_BULK = LIBUSB::TRANSFER_TYPE_BULK
  USB_ENDPOINT_TYPE_INTERRUPT = LIBUSB::TRANSFER_TYPE_INTERRUPT

  USB_REQ_GET_STATUS = LIBUSB::REQUEST_GET_STATUS
  USB_REQ_CLEAR_FEATURE = LIBUSB::REQUEST_CLEAR_FEATURE
  USB_REQ_SET_FEATURE = LIBUSB::REQUEST_SET_FEATURE
  USB_REQ_SET_ADDRESS = LIBUSB::REQUEST_SET_ADDRESS
  USB_REQ_GET_DESCRIPTOR = LIBUSB::REQUEST_GET_DESCRIPTOR
  USB_REQ_SET_DESCRIPTOR = LIBUSB::REQUEST_SET_DESCRIPTOR
  USB_REQ_GET_CONFIGURATION = LIBUSB::REQUEST_GET_CONFIGURATION
  USB_REQ_SET_CONFIGURATION = LIBUSB::REQUEST_SET_CONFIGURATION
  USB_REQ_GET_INTERFACE = LIBUSB::REQUEST_GET_INTERFACE
  USB_REQ_SET_INTERFACE = LIBUSB::REQUEST_SET_INTERFACE
  USB_REQ_SYNCH_FRAME = LIBUSB::REQUEST_SYNCH_FRAME
  USB_TYPE_STANDARD = LIBUSB::REQUEST_TYPE_STANDARD
  USB_TYPE_CLASS = LIBUSB::REQUEST_TYPE_CLASS
  USB_TYPE_VENDOR = LIBUSB::REQUEST_TYPE_VENDOR
  USB_TYPE_RESERVED = LIBUSB::REQUEST_TYPE_RESERVED
  USB_RECIP_DEVICE = LIBUSB::RECIPIENT_DEVICE
  USB_RECIP_INTERFACE = LIBUSB::RECIPIENT_INTERFACE
  USB_RECIP_ENDPOINT = LIBUSB::RECIPIENT_ENDPOINT
  USB_RECIP_OTHER = LIBUSB::RECIPIENT_OTHER

  HAS_GET_DRIVER_NP = RUBY_PLATFORM=~/mswin|mingw/ ? false : true
  HAS_DETACH_KERNEL_DRIVER_NP = RUBY_PLATFORM=~/mswin|mingw/ ? false : true

  # not defined by libusb-1.0, but typical values are:
  USB_MAXENDPOINTS = 32
  USB_MAXINTERFACES = 32
  USB_MAXALTSETTING = 128
  USB_MAXCONFIG = 8


  def USB.busses
    [DefaultBus]
  end

  def USB.devices; DefaultContext.devices.map{|c| Device.new(c) }; end
  def USB.configurations() USB.devices.map {|d| d.configurations }.flatten end
  def USB.interfaces() USB.configurations.map {|d| d.interfaces }.flatten end
  def USB.settings() USB.interfaces.map {|d| d.settings }.flatten end
  def USB.endpoints() USB.settings.map {|d| d.endpoints }.flatten end

  def USB.find_bus(n)
    DefaultBus
  end

  def USB.each_device_by_class(devclass, subclass=nil, protocol=nil)
    devs = DefaultContext.devices :bClass=>devclass, :bSubClass=>subclass, :bProtocol=>protocol
    devs.each do |dev|
      yield Device.new(dev)
    end
    nil
  end

  class Bus
    def initialize(context)
      @ct = context
    end
    def devices
      @ct.devices.map{|d| Device.new(d) }
    end

    def configurations() self.devices.map{|d| d.configurations }.flatten end
    def interfaces() self.configurations.map {|d| d.interfaces }.flatten end
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end

    def find_device(n)
      raise NotImplementedError
    end
  end

  DefaultBus = Bus.new(DefaultContext)

  def USB.dev_string(base_class, sub_class, protocol)
    LIBUSB.dev_string(base_class, sub_class, protocol)
  end

  class Device
    extend Forwardable
    include Comparable

    def initialize(dev)
      @dev = dev
    end

    def_delegators :@dev, :bLength, :bDescriptorType, :bcdUSB, :bDeviceClass,
        :bDeviceSubClass, :bDeviceProtocol, :bMaxPacketSize0, :idVendor, :idProduct,
        :bcdDevice, :iManufacturer, :iProduct, :iSerialNumber, :bNumConfigurations,
        :manufacturer, :product, :serial_number,
        :inspect

    def <=>(o)
      @dev<=>o.instance_variable_get(:@dev)
    end

    def open
      h = DevHandle.new(@dev.open)
      if block_given?
        begin
          r = yield h
        ensure
          h.usb_close
        end
      else
        h
      end
    end

    def bus; DefaultBus; end
    def configurations; @dev.configurations.map{|c| Configuration.new(c) }; end
    def interfaces; @dev.interfaces.map{|c| Interface.new(c) }; end
    def settings; @dev.settings.map{|c| Setting.new(c) }; end
    def endpoints; @dev.endpoints.map{|c| Endpoint.new(c) }; end
  end

  class Configuration
    extend Forwardable
    include Comparable

    def initialize(cd)
      @cd = cd
    end

    def_delegators :@cd, :bLength, :bDescriptorType, :wTotalLength, :bNumInterfaces,
        :bConfigurationValue, :iConfiguration, :bmAttributes, :maxPower,
        :inspect

    def <=>(o)
      @cd<=>o.instance_variable_get(:@cd)
    end

    def bus; DefaultBus; end
    def device() Device.new(@cd.device) end
    def interfaces; @cd.interfaces.map{|c| Interface.new(c) }; end
    def settings() self.interfaces.map {|d| d.settings }.flatten end
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end
  end

  class Interface
    extend Forwardable
    include Comparable

    def initialize(i)
      @i = i
    end

    def_delegators :@i, :inspect

    def <=>(o)
      @i<=>o.instance_variable_get(:@i)
    end

    def bus() self.configuration.device.bus end
    def device() self.configuration.device end
    def configuration; Configuration.new(@i.configuration); end
    def settings; @i.alt_settings.map{|c| Setting.new(c) }; end
    def endpoints() self.settings.map {|d| d.endpoints }.flatten end
  end

  class Setting
    extend Forwardable
    include Comparable

    def initialize(id)
      @id = id
    end

    def_delegators :@id, :bLength, :bDescriptorType, :bInterfaceNumber, :bAlternateSetting,
        :bNumEndpoints, :bInterfaceClass, :bInterfaceSubClass, :bInterfaceProtocol,
        :iInterface, :inspect

    def <=>(o)
      @id<=>o.instance_variable_get(:@id)
    end

    def bus() self.interface.configuration.device.bus end
    def device() self.interface.configuration.device end
    def configuration() self.interface.configuration end
    def interface; Interface.new(@id.interface); end
    def endpoints() @id.endpoints.map {|d| Endpoint.new(d) }.flatten end
  end

  class Endpoint
    extend Forwardable
    include Comparable

    def initialize(ep)
      @ep = ep
    end

    def_delegators :@ep, :bLength, :bDescriptorType, :bEndpointAddress, :bmAttributes,
        :wMaxPacketSize, :bInterval, :bRefresh, :bSynchAddress,
        :inspect

    def <=>(o)
      @ep<=>o.instance_variable_get(:@ep)
    end

    def bus() self.setting.interface.configuration.device.bus end
    def device() self.setting.interface.configuration.device end
    def configuration() self.setting.interface.configuration end
    def interface() self.setting.interface end
    def setting; Setting.new(@ep.setting); end
  end

  class DevHandle
    def initialize(dev)
      @dev = dev
    end

    def usb_close; @dev.close; end
    def usb_set_configuration(c); @dev.configuration=c; end
    def usb_set_altinterface(c); @dev.set_interface_alt_setting=c; end
    def usb_clear_halt(c); @dev.clear_halt(c); end
    def usb_reset; @dev.reset_device; end
    def usb_claim_interface(c); @dev.claim_interface(c); end
    def usb_release_interface(c); @dev.release_interface(c); end
    def usb_get_string(index, langid, buffer)
      t = @dev.string_descriptor(index, langid)
      buffer[0, t.length] = t
      t.length
    end
    def usb_get_string_simple(index, buffer)
      t = @dev.string_descriptor_ascii(index)
      buffer[0, t.length] = t
      t.length
    end

    def usb_control_msg(requesttype, request, value, index, bytes, timeout)
      if requesttype&LIBUSB::ENDPOINT_IN != 0
        # transfer direction in
        res = @dev.control_transfer(:bmRequestType=>requesttype, :bRequest=>request,
            :wValue=>value, :wIndex=>index, :dataIn=>bytes.bytesize, :timeout=>timeout)
        bytes[0, res.bytesize] = res
        res.bytesize
      else
        # transfer direction out
        @dev.control_transfer(:bmRequestType=>requesttype, :bRequest=>request, :wValue=>value,
            :wIndex=>index, :dataOut=>bytes, :timeout=>timeout)
      end
    end

    def usb_bulk_write(endpoint, bytes, timeout)
      @dev.bulk_transfer(:endpoint=>endpoint, :dataOut=>bytes, :timeout=>timeout)
    end
    def usb_bulk_read(endpoint, bytes, timeout)
      res = @dev.bulk_transfer(:endpoint=>endpoint, :dataIn=>bytes.bytesize, :timeout=>timeout)
      bytes[0, res.bytesize] = res
      res.bytesize
    end

    def usb_interrupt_write(endpoint, bytes, timeout)
      @dev.interrupt_transfer(:endpoint=>endpoint, :dataOut=>bytes, :timeout=>timeout)
    end
    def usb_interrupt_read(endpoint, bytes, timeout)
      res = @dev.interrupt_transfer(:endpoint=>endpoint, :dataIn=>bytes.bytesize, :timeout=>timeout)
      bytes[0, res.bytesize] = res
      res.bytesize
    end

#   rb_define_method(rb_cUSB_DevHandle, "usb_get_descriptor", rusb_get_descriptor, 3);
#   rb_define_method(rb_cUSB_DevHandle, "usb_get_descriptor_by_endpoint", rusb_get_descriptor_by_endpoint, 4);

    if HAS_DETACH_KERNEL_DRIVER_NP
      def usb_detach_kernel_driver_np(interface, dummy=nil)
        @dev.detach_kernel_driver(interface)
      end
    end

    if HAS_GET_DRIVER_NP
      def usb_get_driver_np(interface, buffer)
        if @dev.kernel_driver_active?(interface)
          t = "unknown driver"
          buffer[0, t.length] = t
        else
          raise Errno::ENODATA, "No data available"
        end
        nil
      end
    end

    alias set_configuration usb_set_configuration
    alias set_altinterface usb_set_altinterface
    alias clear_halt usb_clear_halt
    alias claim_interface usb_claim_interface
    alias release_interface usb_release_interface

    def get_string_simple(index)
      @dev.string_descriptor_ascii(index)
    end
  end
end
