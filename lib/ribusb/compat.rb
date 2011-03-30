#!/usr/bin/env ruby
#   RibUSB -- Ruby bindings to libusb.
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
#   Please visit the project website at http://ribusb.rubyforge.org/
#   for support.

require 'ribusb'
require 'forwardable'

# Compatibility layer for ruby-usb[http://www.a-k-r.org/ruby-usb/] (API based on libusb-0.1)
#
# This module provides some limited compatibility to ruby-usb.
#
# Usage example:
#   begin
#     require 'usb'
#   rescue LoadError
#     require 'ribusb/compat'
#   end
#   p USB.devices => [#<USB::Device ...>]
#
# Known issues:
# * Exceptions are different between ruby-usb and RibUSB and are not converted
# * libusb-1.0 doesn't explicitly manage USB-buses, so only one Bus is used currently
module USB
  DefaultContext = RibUSB::Context.new
  
  USB_CLASS_PER_INTERFACE = RibUSB::LIBUSB_CLASS_PER_INTERFACE
  USB_CLASS_AUDIO = RibUSB::LIBUSB_CLASS_AUDIO
  USB_CLASS_COMM = RibUSB::LIBUSB_CLASS_COMM
  USB_CLASS_HID = RibUSB::LIBUSB_CLASS_HID
  USB_CLASS_PRINTER = RibUSB::LIBUSB_CLASS_PRINTER
  USB_CLASS_PTP = RibUSB::LIBUSB_CLASS_PTP
  USB_CLASS_MASS_STORAGE = RibUSB::LIBUSB_CLASS_MASS_STORAGE
  USB_CLASS_HUB = RibUSB::LIBUSB_CLASS_HUB
  USB_CLASS_DATA = RibUSB::LIBUSB_CLASS_DATA
  USB_CLASS_VENDOR_SPEC = RibUSB::LIBUSB_CLASS_VENDOR_SPEC
  
  USB_DT_DEVICE = RibUSB::LIBUSB_DT_DEVICE
  USB_DT_CONFIG = RibUSB::LIBUSB_DT_CONFIG
  USB_DT_STRING = RibUSB::LIBUSB_DT_STRING
  USB_DT_INTERFACE = RibUSB::LIBUSB_DT_INTERFACE
  USB_DT_ENDPOINT = RibUSB::LIBUSB_DT_ENDPOINT
  USB_DT_HID = RibUSB::LIBUSB_DT_HID
  USB_DT_REPORT = RibUSB::LIBUSB_DT_REPORT
  USB_DT_PHYSICAL = RibUSB::LIBUSB_DT_PHYSICAL
  USB_DT_HUB = RibUSB::LIBUSB_DT_HUB
  USB_DT_DEVICE_SIZE = RibUSB::LIBUSB_DT_DEVICE_SIZE
  USB_DT_CONFIG_SIZE = RibUSB::LIBUSB_DT_CONFIG_SIZE
  USB_DT_INTERFACE_SIZE = RibUSB::LIBUSB_DT_INTERFACE_SIZE
  USB_DT_ENDPOINT_SIZE = RibUSB::LIBUSB_DT_ENDPOINT_SIZE
  USB_DT_ENDPOINT_AUDIO_SIZE = RibUSB::LIBUSB_DT_ENDPOINT_AUDIO_SIZE
  USB_DT_HUB_NONVAR_SIZE = RibUSB::LIBUSB_DT_HUB_NONVAR_SIZE
  
  USB_ENDPOINT_ADDRESS_MASK = RibUSB::LIBUSB_ENDPOINT_ADDRESS_MASK
  USB_ENDPOINT_DIR_MASK = RibUSB::LIBUSB_ENDPOINT_DIR_MASK
  USB_ENDPOINT_IN = RibUSB::LIBUSB_ENDPOINT_IN
  USB_ENDPOINT_OUT = RibUSB::LIBUSB_ENDPOINT_OUT
  
  USB_ENDPOINT_TYPE_MASK = RibUSB::LIBUSB_TRANSFER_TYPE_MASK
  USB_ENDPOINT_TYPE_CONTROL = RibUSB::LIBUSB_TRANSFER_TYPE_CONTROL
  USB_ENDPOINT_TYPE_ISOCHRONOUS = RibUSB::LIBUSB_TRANSFER_TYPE_ISOCHRONOUS
  USB_ENDPOINT_TYPE_BULK = RibUSB::LIBUSB_TRANSFER_TYPE_BULK
  USB_ENDPOINT_TYPE_INTERRUPT = RibUSB::LIBUSB_TRANSFER_TYPE_INTERRUPT

  USB_REQ_GET_STATUS = RibUSB::LIBUSB_REQUEST_GET_STATUS
  USB_REQ_CLEAR_FEATURE = RibUSB::LIBUSB_REQUEST_CLEAR_FEATURE
  USB_REQ_SET_FEATURE = RibUSB::LIBUSB_REQUEST_SET_FEATURE
  USB_REQ_SET_ADDRESS = RibUSB::LIBUSB_REQUEST_SET_ADDRESS
  USB_REQ_GET_DESCRIPTOR = RibUSB::LIBUSB_REQUEST_GET_DESCRIPTOR
  USB_REQ_SET_DESCRIPTOR = RibUSB::LIBUSB_REQUEST_SET_DESCRIPTOR
  USB_REQ_GET_CONFIGURATION = RibUSB::LIBUSB_REQUEST_GET_CONFIGURATION
  USB_REQ_SET_CONFIGURATION = RibUSB::LIBUSB_REQUEST_SET_CONFIGURATION
  USB_REQ_GET_INTERFACE = RibUSB::LIBUSB_REQUEST_GET_INTERFACE
  USB_REQ_SET_INTERFACE = RibUSB::LIBUSB_REQUEST_SET_INTERFACE
  USB_REQ_SYNCH_FRAME = RibUSB::LIBUSB_REQUEST_SYNCH_FRAME
  USB_TYPE_STANDARD = RibUSB::LIBUSB_REQUEST_TYPE_STANDARD
  USB_TYPE_CLASS = RibUSB::LIBUSB_REQUEST_TYPE_CLASS
  USB_TYPE_VENDOR = RibUSB::LIBUSB_REQUEST_TYPE_VENDOR
  USB_TYPE_RESERVED = RibUSB::LIBUSB_REQUEST_TYPE_RESERVED
  USB_RECIP_DEVICE = RibUSB::LIBUSB_RECIPIENT_DEVICE
  USB_RECIP_INTERFACE = RibUSB::LIBUSB_RECIPIENT_INTERFACE
  USB_RECIP_ENDPOINT = RibUSB::LIBUSB_RECIPIENT_ENDPOINT
  USB_RECIP_OTHER = RibUSB::LIBUSB_RECIPIENT_OTHER
  
  LIBUSB_HAS_GET_DRIVER_NP = RUBY_PLATFORM=~/mswin|mingw/ ? false : true
  LIBUSB_HAS_DETACH_KERNEL_DRIVER_NP = RUBY_PLATFORM=~/mswin|mingw/ ? false : true
  
# not defined by libusb-1.0:
#   USB_MAXENDPOINTS
#   USB_MAXINTERFACES
#   USB_MAXALTSETTING
#   USB_MAXCONFIG

  def USB.busses
    [DefaultBus]
  end

  def USB.devices; DefaultContext.find.map{|c| Device.new(c) }; end
  def USB.configurations() USB.devices.map {|d| d.configurations }.flatten end
  def USB.interfaces() USB.configurations.map {|d| d.interfaces }.flatten end
  def USB.settings() USB.interfaces.map {|d| d.settings }.flatten end
  def USB.endpoints() USB.settings.map {|d| d.endpoints }.flatten end

  def USB.find_bus(n)
    DefaultBus
  end
  
  def USB.each_device_by_class(devclass, subclass=nil, protocol=nil)
    devs = DefaultContext.find_with_interfaces :bDeviceClass=>devclass, :bDeviceSubClass=>subclass, :bDeviceProtocol=>protocol
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
      @ct.find.map{|d| Device.new(d) }
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
    RibUSB.dev_string(base_class, sub_class, protocol)
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
      h = DevHandle.new(@dev)
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
    def settings; @dev.interface_descriptors.map{|c| Setting.new(c) }; end
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
    def setting; Setting.new(@ep.interface_descriptor); end
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
    def usb_release_interface(c); @dev.release_interface(c); end
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
      @dev.control_transfer(:bmRequestType=>requesttype, :bRequest=>request, :wValue=>value,
          :wIndex=>index, :dataIn=>bytes, :timeout=>timeout)
    end
    def usb_bulk_write(endpoint, bytes, timeout)
      @dev.bulk_transfer(:endpoint=>endpoint, :dataOut=>bytes, :timeout=>timeout)
    end
    def usb_bulk_read(endpoint, bytes, timeout)
      @dev.bulk_transfer(:endpoint=>endpoint, :dataIn=>bytes, :timeout=>timeout)
    end
    def usb_interrupt_write(endpoint, bytes, timeout)
      @dev.interrupt_transfer(:endpoint=>endpoint, :dataOut=>bytes, :timeout=>timeout)
    end
    def usb_interrupt_read(endpoint, bytes, timeout)
      @dev.interrupt_transfer(:endpoint=>endpoint, :dataIn=>bytes, :timeout=>timeout)
    end

#   rb_define_method(rb_cUSB_DevHandle, "usb_get_descriptor", rusb_get_descriptor, 3);
#   rb_define_method(rb_cUSB_DevHandle, "usb_get_descriptor_by_endpoint", rusb_get_descriptor_by_endpoint, 4);

    if LIBUSB_HAS_DETACH_KERNEL_DRIVER_NP
      def usb_detach_kernel_driver_np(interface, dummy=nil)
        @dev.detach_kernel_driver(interface)
      end
    end

    if LIBUSB_HAS_GET_DRIVER_NP
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

    def set_configuration(configuration)
      configuration = configuration.bConfigurationValue if configuration.respond_to? :bConfigurationValue
      self.usb_set_configuration(configuration)
    end

    def set_altinterface(alternate)
      alternate = alternate.bAlternateSetting if alternate.respond_to? :bAlternateSetting
      self.usb_set_altinterface(alternate)
    end

    def clear_halt(ep)
      ep = ep.bEndpointAddress if ep.respond_to? :bEndpointAddress
      self.usb_clear_halt(ep)
    end

    def claim_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      self.usb_claim_interface(interface)
    end

    def release_interface(interface)
      interface = interface.bInterfaceNumber if interface.respond_to? :bInterfaceNumber
      self.usb_release_interface(interface)
    end

    def get_string_simple(index)
      @dev.string_descriptor_ascii(index)
    end
  end
end
