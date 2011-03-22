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

  attr_accessor :usb
  attr_accessor :dev
  attr_accessor :endpoint_in
  attr_accessor :endpoint_out

  def setup
    @usb = Bus.new
    @usb.debug = 3

    usb.find do |dev|
      dev.bNumConfigurations.times do |config_index|
        config_desc = dev.configDescriptor(config_index)
        config_desc.interfaceList.each do |interface|
          interface.altSettingList.each do |if_desc|
            if if_desc.bInterfaceClass == LIBUSB_CLASS_MASS_STORAGE &&
                  ( if_desc.bInterfaceSubClass == 0x01 || if_desc.bInterfaceSubClass == 0x06 ) &&
                  if_desc.bInterfaceProtocol == 0x50

              @dev = dev
              @if_desc = if_desc
            end
          end
        end
      end
    end

    abort "no mass storage device found" unless @dev

    @endpoint_in = @if_desc.endpointList.find{|ep| ep.bEndpointAddress&LIBUSB_ENDPOINT_IN != 0 }.bEndpointAddress
    @endpoint_out = @if_desc.endpointList.find{|ep| ep.bEndpointAddress&LIBUSB_ENDPOINT_IN == 0 }.bEndpointAddress

    if dev.kernelDriverActive?(0)
      dev.detachKernelDriver(0)
    end
    dev.claimInterface(0)
  end

  def teardown
    dev.releaseInterface(0) if dev
    dev.close if dev
  end

  def send_mass_storage_command(dev, cdb, data_length, direction=LIBUSB_ENDPOINT_IN)
    @tag ||= 0
    @tag += 1
    expected_tag = @tag
    lun = 0

    cbw = ['USBC', expected_tag, data_length, direction, lun, cdb.length, cdb].pack('a*VVCCCa*')
    cbw = cbw.ljust(31, "\0")

    num_bytes = dev.bulkTransfer(:endpoint=>endpoint_out, :dataOut=>cbw)
    assert_equal 31, num_bytes, "31 bytes CBW should be sent"

    begin
      recv = dev.bulkTransfer(:endpoint=>endpoint_in, :dataIn=>data_length)
    rescue => err
      if err.to_s=~/pipe error/
        dev.clearHalt(endpoint_in)
      end
    end

    get_mass_storage_status(dev, expected_tag)
    return recv
  end

  def get_mass_storage_status(dev, expected_tag)
    retries = 5
    status = begin
      dev.bulkTransfer(:endpoint=>endpoint_in, :dataIn=>13)
    rescue => err
      if (retries-=1)>=0 && err.to_s=~/pipe error/
        dev.clearHalt(endpoint_in)
        retry
      end
      raise
    end
    assert_equal 13, status.length, "CSW should be 13 bytes long"

    dCSWSignature, dCSWTag, dCSWDataResidue, bCSWStatus = status.unpack('a4VVC')

    assert_equal 'USBS', dCSWSignature, "CSW should start with USBS"
    assert_equal expected_tag, dCSWTag, "CSW-tag should be like CBW-tag"
    raise CSWError, "CSW returned error #{bCSWStatus}" unless bCSWStatus==0
    status
  end

  def send_inquiry(dev)
    expected_length = 0x24 # INQUIRY_LENGTH
    cdb = [ 0x12, 0, 0, # Inquiry
            expected_length, 0,
            ].pack('CCCnC')

    send_mass_storage_command( dev, cdb, expected_length )
  end

  def get_capacity(dev)
    expected_length = 0x08 # READ_CAPACITY_LENGTH
    cdb = [ 0x25, # Read Capacity
            "\0"*9,
            ].pack('Ca*')

    cap = send_mass_storage_command( dev, cdb, expected_length )

    max_lba, block_size = cap.unpack('NN')
    device_size = (max_lba + 1) * block_size / (1024*1024*1024.0);
    printf("   Max LBA: %08X, Block Size: %08X (%.2f GB)\n", max_lba, block_size, device_size);
  end

  def read_block(dev, start, nr_blocks)
    expected_length = 0x200 * nr_blocks
    cdb = [ 0x28, 0, # Read(10)
            start, 0,
            nr_blocks, 0,
            ].pack('CCNCnC')
    data = send_mass_storage_command( dev, cdb, expected_length )
  end

  def read_block_with_wrong_length(dev)
    expected_length = 0x200
    cdb = [ 0x28, 0, # Read(10)
            1234, 0,
            0, 0, # 0 blocks
            ].pack('CCNCnC')
    data = send_mass_storage_command( dev, cdb, expected_length )
  end

  def test_read_access
    send_inquiry(dev)
    get_capacity(dev)

    data = read_block(dev, 0, 1)
    assert_equal 512, data.length, "Read block should be 512 bytes"

    # closing device handle shouldn't matter, in the meantime
    dev.close
    dev.close
    dev.claimInterface(0)

    data = read_block(dev, 0, 2)
    assert_equal 1024, data.length, "Read block should be 1024 bytes"
  end

  def test_read_failed
    assert_raise(CSWError, RuntimeError) do
      read_block_with_wrong_length(dev)
    end
  end

  def test_read_long
    1000.times do |bl|
      data = read_block(dev, bl, 1)
      assert_equal 512, data.length, "Read block should be 512 bytes"
    end
  end
end
