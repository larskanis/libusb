# This test requires a connected, but not mounted mass storage device with
# read/write access allowed. Based on the following specifications:
#   http://www.usb.org/developers/devclass_docs/usbmassbulk_10.pdf
#   http://en.wikipedia.org/wiki/SCSI_command
#

require "test/unit"
require "ribusb"

class TestRibusbMassStorage < Test::Unit::TestCase
  include RibUSB

  class CSWError < RuntimeError; end
  BOMS_RESET = 0xFF
  BOMS_GET_MAX_LUN = 0xFE

  attr_accessor :usb
  attr_accessor :dev
  attr_accessor :endpoint_in
  attr_accessor :endpoint_out

  def setup
    @usb = Context.new
    @usb.debug = 3
    @asynchron = false

    usb.find do |dev|
      dev.interface_descriptors.each do |if_desc|
        if if_desc.bInterfaceClass == LIBUSB_CLASS_MASS_STORAGE &&
              ( if_desc.bInterfaceSubClass == 0x01 || if_desc.bInterfaceSubClass == 0x06 ) &&
              if_desc.bInterfaceProtocol == 0x50

          @dev = dev
          @if_desc = if_desc
        end
      end
    end

    abort "no mass storage device found" unless @dev

    devs = usb.find_with_interfaces( :bDeviceClass=>LIBUSB_CLASS_MASS_STORAGE, :bInterfaceSubClass=>0x01, :bInterfaceProtocol=>0x50 )
    devs += usb.find_with_interfaces( :bDeviceClass=>LIBUSB_CLASS_MASS_STORAGE, :bInterfaceSubClass=>0x06, :bInterfaceProtocol=>0x50 )
    assert_equal @dev, devs.last, "find and find_with_interfaces should deliver the same device"

    @endpoint_in = @if_desc.endpoints.find{|ep| ep.bEndpointAddress&LIBUSB_ENDPOINT_IN != 0 }.bEndpointAddress
    @endpoint_out = @if_desc.endpoints.find{|ep| ep.bEndpointAddress&LIBUSB_ENDPOINT_IN == 0 }.bEndpointAddress

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

  def send_mass_storage_command(cdb, data_length, direction=LIBUSB_ENDPOINT_IN)
    @tag ||= 0
    @tag += 1
    expected_tag = @tag
    lun = 0

    cbw = ['USBC', expected_tag, data_length, direction, lun, cdb.length, cdb].pack('a*VVCCCa*')
    cbw = cbw.ljust(31, "\0")

    num_bytes = bulk_transfer(:endpoint=>endpoint_out, :dataOut=>cbw)
    assert_equal 31, num_bytes, "31 bytes CBW should be sent"

    begin
      recv = bulk_transfer(:endpoint=>endpoint_in, :dataIn=>data_length)
    rescue LIBUSB_ERROR_PIPE => err
      assert_match( /pipe error/, err.to_s, "a LIBUSB_ERROR_PIPE should tell about pipe error")
      dev.clear_halt(endpoint_in)
    end

    get_mass_storage_status(expected_tag)
    return recv
  end

  def get_mass_storage_status(expected_tag)
    buffer = " "*13
    retries = 5
    length = begin
      bulk_transfer(:endpoint=>endpoint_in, :dataIn=>buffer)
    rescue LIBUSB_ERROR_PIPE => err
      if (retries-=1)>=0
        dev.clear_halt(endpoint_in)
        retry
      end
      raise
    end
    assert_equal 13, length, "CSW should be 13 bytes long"

    dCSWSignature, dCSWTag, dCSWDataResidue, bCSWStatus = buffer.unpack('a4VVC')

    assert_equal 'USBS', dCSWSignature, "CSW should start with USBS"
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
            "\0"*9,
            ].pack('Ca*')

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
    data = send_mass_storage_command( cdb, expected_length )
  end

  def invalid_command
    expected_length = 0x100
    cdb = [ 0x26, 0, # invalid command
            ].pack('CC')
    data = send_mass_storage_command( cdb, expected_length )
  end

  def mass_storage_reset
    res = control_transfer(
      :bmRequestType=>LIBUSB_ENDPOINT_OUT|LIBUSB_REQUEST_TYPE_CLASS|LIBUSB_RECIPIENT_INTERFACE,
      :bRequest=>BOMS_RESET,
      :wValue=>0, :wIndex=>0)
    assert_equal 0, res, "BOMS_RESET response should be 0 byte"

    res = control_transfer(
      :bmRequestType=>LIBUSB_ENDPOINT_OUT|LIBUSB_REQUEST_TYPE_CLASS|LIBUSB_RECIPIENT_INTERFACE,
      :bRequest=>BOMS_RESET,
      :wValue=>0, :wIndex=>0, :dataOut=>'')
    assert_equal 0, res, "BOMS_RESET response should be 0 byte"
  end

  def read_max_lun
    lun = " "
    res = control_transfer(
      :bmRequestType=>LIBUSB_ENDPOINT_IN|LIBUSB_REQUEST_TYPE_CLASS|LIBUSB_RECIPIENT_INTERFACE,
      :bRequest=>BOMS_GET_MAX_LUN,
      :wValue=>0, :wIndex=>0, :dataIn=>lun)
    assert_equal 1, res, "BOMS_GET_MAX_LUN response should be 1 byte"
#     puts "   Max LUN = #{lun.unpack("C")[0]}"

    res = control_transfer(
      :bmRequestType=>LIBUSB_ENDPOINT_IN|LIBUSB_REQUEST_TYPE_CLASS|LIBUSB_RECIPIENT_INTERFACE,
      :bRequest=>BOMS_GET_MAX_LUN,
      :wValue=>0, :wIndex=>0, :dataIn=>1)
    assert_equal 1, res.length, "BOMS_GET_MAX_LUN response should be 1 byte"
    assert_equal lun, res, "Both lun results should be equal"
  end

  def test_read_access
    send_inquiry
    get_capacity

    data = read_block(0, 1)
    assert_equal 512, data.length, "Read block should be 512 bytes"

    # closing device handle shouldn't matter, in the meantime
    dev.close
    dev.close
    dev.claim_interface(0)

    data = read_block(0, 2)
    assert_equal 1024, data.length, "Read block should be 1024 bytes"
  end
  def test_read_access_async
    @asynchron = true
    test_read_access
  end

  def test_read_failed
    assert_raise(CSWError, LIBUSB_ERROR_TIMEOUT) do
      invalid_command
    end
  end
  def test_read_failed_async
    @asynchron = true
    test_read_failed
  end

  def test_max_lun
    read_max_lun
  end
  def test_max_lun_async
    @asynchron = true
    read_max_lun
  end

  def test_mass_storage_reset
    mass_storage_reset
  end
  def test_mass_storage_reset_async
    @asynchron = true
    mass_storage_reset
  end

  def test_read_long
    1000.times do |bl|
      data = read_block(bl, 1)
      assert_equal 512, data.length, "Read block should be 512 bytes"
    end
  end
end
