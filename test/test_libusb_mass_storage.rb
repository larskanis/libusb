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
# This test requires a connected, but not mounted mass storage device with
# read/write access allowed. Based on the following specifications:
#   http://www.usb.org/developers/devclass_docs/usbmassbulk_10.pdf
#   http://en.wikipedia.org/wiki/SCSI_command
#

require "test/unit"
require "libusb"

class TestLibusbMassStorage < Test::Unit::TestCase
  include LIBUSB

  class CSWError < RuntimeError; end
  BOMS_RESET = 0xFF
  BOMS_GET_MAX_LUN = 0xFE

  attr_accessor :usb
  attr_accessor :device
  attr_accessor :dev
  attr_accessor :endpoint_in
  attr_accessor :endpoint_out

  def setup
    @usb = Context.new
    @usb.debug = 3
    @asynchron = false

    @device = usb.devices( :bClass=>CLASS_MASS_STORAGE, :bSubClass=>[0x06,0x01], :bProtocol=>0x50 ).last
    skip "no mass storage device found" unless @device

    @endpoint_in = @device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN != 0 }
    @endpoint_out = @device.endpoints.find{|ep| ep.bEndpointAddress&ENDPOINT_IN == 0 }
    @dev = @device.open

    if RUBY_PLATFORM=~/linux/i && dev.kernel_driver_active?(0)
      dev.detach_kernel_driver(0)
    end
    dev.claim_interface(0)

    # clear any pending data
    dev.clear_halt(endpoint_in)
  end

  def teardown
    dev.release_interface(0) if dev
    dev.close if dev
  end

  def do_transfer(method, args)
    if @asynchron
      stop = false
      transfer = dev.send(method, args) do |tr|
        stop = true
        assert_equal transfer, tr, "block argument should be the transfer instance"
#         p transfer.status
      end

      transfer.submit
      usb.handle_events
      until stop
        sleep 0.001
        usb.handle_events
      end
      transfer.result
    else
      dev.send(method, args)
    end
  end
  def control_transfer(args)
    do_transfer(:control_transfer, args)
  end
  def bulk_transfer(args)
    do_transfer(:bulk_transfer, args)
  end

  def send_mass_storage_command(cdb, data_length, direction=ENDPOINT_IN)
    @tag ||= 0
    @tag += 1
    expected_tag = @tag
    lun = 0

    cbw = ['USBC', expected_tag, data_length, direction, lun, cdb.length, cdb].pack('a*VVCCCa*')
    cbw = cbw.ljust(31, "\0")

    num_bytes = bulk_transfer(:endpoint=>endpoint_out, :dataOut=>cbw)
    assert_equal 31, num_bytes, "31 bytes CBW should be sent"

    recv = bulk_transfer(:endpoint=>endpoint_in, :dataIn=>data_length)

    get_mass_storage_status(expected_tag)
    return recv
  end

  def get_mass_storage_status(expected_tag)
    retries = 5
    buffer = begin
      bulk_transfer(:endpoint=>endpoint_in, :dataIn=>13)
    rescue LIBUSB::ERROR_PIPE
      if (retries-=1)>=0
        dev.clear_halt(endpoint_in)
        retry
      end
      raise
    end
    assert_equal 13, buffer.bytesize, "CSW should be 13 bytes long"

    dCSWSignature, dCSWTag, dCSWDataResidue, bCSWStatus = buffer.unpack('a4VVC')

    assert_equal 'USBS', dCSWSignature, "CSW should start with USBS"
    assert_kind_of Integer, dCSWDataResidue
    assert_equal expected_tag, dCSWTag, "CSW-tag should be like CBW-tag"
    raise CSWError, "CSW returned error #{bCSWStatus}" unless bCSWStatus==0
    buffer
  end

  def send_inquiry
    expected_length = 0x24 # INQUIRY_LENGTH
    cdb = [ 0x12, 0, 0, # Inquiry
            expected_length, 0,
            ].pack('CCCnC')

    send_mass_storage_command( cdb, expected_length )
  end

  def get_capacity
    expected_length = 0x08 # READ_CAPACITY_LENGTH
    cdb = [ 0x25, # Read Capacity
            ].pack('Cx9')

    cap = send_mass_storage_command( cdb, expected_length )

    max_lba, block_size = cap.unpack('NN')
    device_size = (max_lba + 1) * block_size / (1024*1024*1024.0);
    printf("   Max LBA: %08X, Block Size: %08X (%.2f GB)\n", max_lba, block_size, device_size);
  end

  def read_block(start, nr_blocks)
    expected_length = 0x200 * nr_blocks
    cdb = [ 0x28, 0, # Read(10)
            start, 0,
            nr_blocks, 0,
            ].pack('CCNCnC')
    send_mass_storage_command( cdb, expected_length )
  end

  def invalid_command
    expected_length = 0x100
    cdb = [ 0x26, 0, # invalid command
            ].pack('CC')
    send_mass_storage_command( cdb, expected_length )
  end

  def mass_storage_reset
    res = control_transfer(
      :bmRequestType=>ENDPOINT_OUT|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
      :bRequest=>BOMS_RESET,
      :wValue=>0, :wIndex=>0)
    assert_equal 0, res, "BOMS_RESET response should be 0 byte"

    res = control_transfer(
      :bmRequestType=>ENDPOINT_OUT|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
      :bRequest=>BOMS_RESET,
      :wValue=>0, :wIndex=>0, :dataOut=>'')
    assert_equal 0, res, "BOMS_RESET response should be 0 byte"
  end

  def read_max_lun
    res = control_transfer(
      :bmRequestType=>ENDPOINT_IN|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
      :bRequest=>BOMS_GET_MAX_LUN,
      :wValue=>0, :wIndex=>0, :dataIn=>1)
    assert [0].pack("C")==res || [1].pack("C")==res, "BOMS_GET_MAX_LUN response is usually 0 or 1"
  end

  def test_read_access
    send_inquiry
    get_capacity

    data = read_block(0, 1)
    assert_equal 512, data.length, "Read block should be 512 bytes"

    # closing device handle shouldn't matter, in the meantime
    dev.close
    @dev = @device.open
    dev.claim_interface(0)

    data = read_block(0, 2)
    assert_equal 1024, data.length, "Read block should be 1024 bytes"
  end
#   def test_read_access_async
#     @asynchron = true
#     test_read_access
#   end

  def test_read_failed
    count = 0
    th = Thread.new do
      loop do
        count+=1
        sleep 0.01
      end
    end
    assert_raise(LIBUSB::ERROR_TIMEOUT) do
      begin
        bulk_transfer(:endpoint=>endpoint_in, :dataIn=>123)
      rescue LIBUSB::ERROR_TIMEOUT => err
        assert_kind_of String, err.transferred
        raise
      end
    end

    th.kill
    dev.clear_halt(endpoint_in)
    dev.clear_halt(endpoint_out)
    assert_operator 20, :<=, count, "libusb_handle_events should not block a parallel Thread"
  end
#   def test_read_failed_async
#     @asynchron = true
#     test_read_failed
#   end

  def test_max_lun
    read_max_lun
  end
#   def test_max_lun_async
#     @asynchron = true
#     read_max_lun
#   end

  def test_mass_storage_reset
    mass_storage_reset
  end
#   def test_mass_storage_reset_async
#     @asynchron = true
#     mass_storage_reset
#   end

  def test_read_long
    1000.times do |bl|
      data = read_block(bl, 1)
      assert_equal 512, data.length, "Read block should be 512 bytes"
    end
  end

  def test_attach_kernel_driver
    dev.release_interface(0)
    if RUBY_PLATFORM=~/linux/i
      dev.attach_kernel_driver(0)
      assert dev.kernel_driver_active?(0), "kernel driver should be active again"
    end
    dev.close
    @dev = nil
  end

  def test_wrong_argument
    assert_raise(ArgumentError){ dev.bulk_transfer(:endpoint=>endpoint_in, :dataOut=>"data") }
    assert_raise(ArgumentError){ dev.interrupt_transfer(:endpoint=>endpoint_in, :dataOut=>"data") }
    assert_raise(ArgumentError){ dev.control_transfer(
      :bmRequestType=>ENDPOINT_OUT|REQUEST_TYPE_CLASS|RECIPIENT_INTERFACE,
      :bRequest=>BOMS_RESET,
      :wValue=>0, :wIndex=>0, :dataIn=>123) }
  end
end
