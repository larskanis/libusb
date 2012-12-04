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
#
# This test requires two connected, but not mounted mass storage device with
# read/write access allowed.

require "test/unit"
require "libusb"

class TestLibusbThreads < Test::Unit::TestCase
  include LIBUSB

  BOMS_GET_MAX_LUN = 0xFE

  attr_accessor :usb
  attr_accessor :devices
  attr_accessor :devs
  attr_accessor :endpoints_in
  attr_accessor :endpoints_out

  def setup
    @usb = Context.new
    @usb.debug = 3

    @devices = usb.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>[0x06,0x01], :bProtocol=>0x50 )
    skip "less than two mass storage devices found" unless @devices.length >= 2

    @devs = @devices.map do |device|
      dev = device.open
      if RUBY_PLATFORM=~/linux/i && dev.kernel_driver_active?(0)
        dev.detach_kernel_driver(0)
      end
      dev.claim_interface(0)
      dev
    end

    @endpoints_in = {}
    @endpoints_out = {}

    @devs.each do |dev|
      @endpoints_in[dev] = dev.device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN != 0 }
      @endpoints_out[dev] = dev.device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN == 0 }
    end

    Thread.abort_on_exception = true
  end

  def teardown
    if devs
      devs.each do |dev|
        dev.release_interface(0)
        dev.close
      end
    end
  end

  def thread_worker(dev)
    endpoint = endpoints_in[dev]
    1.times do
      st = Time.now
      assert_raise LIBUSB::ERROR_TIMEOUT do
        dev.bulk_transfer(:endpoint=>endpoint, :dataIn=>123, :timeout=>100)
      end
      assert_operator Time.now-st, :<, 5
      dev.clear_halt(endpoint)
    end
  end

  def test_sync_api
    threads = devs.map do |dev|
      Thread.new do
        thread_worker(dev)
      end
    end
    threads.map(&:join)
  end
end
