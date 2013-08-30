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

require "minitest/autorun"
require "libusb"
require "libusb/eventmachine"
require "eventmachine"

class TestLibusbEventMachine < Minitest::Test
  include LIBUSB
  BOMS_GET_MAX_LUN = 0xFE

  attr_accessor :context
  attr_accessor :device
  attr_accessor :devh
  attr_accessor :endpoint_in
  attr_accessor :endpoint_out

  def setup
    @context = Context.new
    @context.debug = 3

    @device = context.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>[0x06,0x01], :bProtocol=>0x50 ).last
    skip "no mass storage device found" unless @device

    @endpoint_in = @device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN != 0 }
    @endpoint_out = @device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN == 0 }
    @devh = @device.open

    if RUBY_PLATFORM=~/linux/i && devh.kernel_driver_active?(0)
      devh.detach_kernel_driver(0)
    end
    devh.claim_interface(0)

    # clear any pending data
    devh.clear_halt(endpoint_in)
  end

  def teardown
  end

  def em_run
    EventMachine.run do
      @context.eventmachine_register

      EventMachine.add_shutdown_hook do
        @devh.release_interface(0) if @devh
        @devh.close if @devh
        @context.eventmachine_unregister
      end

      yield
    end
  end


  def test_bulk_transfer
    em_run do
      ticks = 0
      tr = devh.eventmachine_bulk_transfer(
          :endpoint => @endpoint_in,
          :timeout => 1500,
          :dataIn => 123 )
#       puts "started usb transfer #{tr}"

      tr.callback do |data|
#         puts "recved: #{data.inspect}"

        assert false, "the bulk transfer shouldn't succeed"
        EventMachine.stop
      end
      tr.errback do |text|
#         puts "recv-err: #{text}"
        assert true, "the bulk transfer should fail"

        assert_operator ticks, :>=, 4
        EventMachine.stop
      end

      EventMachine.add_periodic_timer(0.333) do
        ticks += 1
      end
    end
  end

  def test_event_loop
    em_run do
      tr = devh.eventmachine_control_transfer(
        :bmRequestType=>ENDPOINT_IN|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
        :bRequest=>BOMS_GET_MAX_LUN,
        :wValue=>0, :wIndex=>0, :dataIn=>1 )

#       puts "started usb transfer #{tr}"
      tr.callback do |data|
#         puts "recved: #{data.inspect}"
        assert true, "the control transfer should succeed"
        EventMachine.stop
      end
      tr.errback do |text|
#         puts "recv-err: #{text}"
        assert false, "the control transfer shouldn't fail"
        EventMachine.stop
      end
    end
  end
end
