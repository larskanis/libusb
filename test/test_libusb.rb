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

class TestLibusb < Minitest::Test
  def test_has_capability
    assert LIBUSB.has_capability?(:CAP_HAS_CAPABILITY)
  end

  def test_version_parts
    v = LIBUSB.version
    assert_operator v.major, :>=, 0
    assert_operator v.minor, :>=, 0
    assert_operator v.micro, :>=, 0
    assert_operator v.nano, :>=, 0
    assert_kind_of String, v.rc
  end

  def test_version_string
    v = LIBUSB.version
    assert_match(/^\d+\.\d+\.\d+/, v.to_s)
    assert_match(/^#<LIBUSB::Version \d+\.\d+\.\d+/, v.inspect)
  end

  def test_gem_version_string
    assert_match(/^\d+\.\d+\.\d+/, LIBUSB::VERSION)
  end

  def test_log_callback
    skip "only supported on Linux" unless RUBY_PLATFORM=~/linux/
    skip "libusb version older than 1.0.27" if Gem::Version.new(LIBUSB.version) < Gem::Version.new("1.0.27")

    begin
      called = Hash.new { |h, k| h[k] = [] }
      LIBUSB.set_options OPTION_LOG_CB: proc{|*a| called[:global] << a }, OPTION_LOG_LEVEL: LIBUSB::LOG_LEVEL_DEBUG

      c = LIBUSB::Context.new OPTION_LOG_CB: proc{|*a| called[:ctx1] << a }, OPTION_NO_DEVICE_DISCOVERY: nil
      c.devices
      c.set_log_cb(LIBUSB::LOG_CB_CONTEXT){|*a| called[:ctx2] << a }
      c.devices

      #pp called
      assert_nil called[:global][0][0]
      assert_equal :LOG_LEVEL_DEBUG, called[:global][0][1]
      assert_match(/timestamp.*threadID/, called[:global][0][2])
      assert_match(/no device discovery/, called[:global].join)

      assert_operator called[:ctx1].size, :>, called[:ctx2].size
      assert_equal c, called[:ctx1][-1][0]
      assert_equal :LOG_LEVEL_DEBUG, called[:ctx1][-1][1]
      assert_match(/libusb_get_device_list/, called[:ctx1][-1][2])
      assert_match(/no device discovery/, called[:ctx1].join)

      assert_equal c, called[:ctx2][-1][0]
      assert_equal :LOG_LEVEL_DEBUG, called[:ctx2][-1][1]
      assert_match(/libusb_get_device_list/, called[:ctx2][-1][2])

    ensure
      LIBUSB.set_options OPTION_LOG_CB: [nil], OPTION_LOG_LEVEL: LIBUSB::LOG_LEVEL_NONE
    end
  end
end
