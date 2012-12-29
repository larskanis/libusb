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
  class Version < FFI::Struct
    layout :major, :uint16,
        :minor, :uint16,
        :micro, :uint16,
        :nano, :uint16,
        :rc, :pointer,
        :describe, :pointer

    # Library major version.
    def major
      self[:major]
    end
    # Library minor version.
    def minor
      self[:minor]
    end
    # Library micro version.
    def micro
      self[:micro]
    end
    # Library nano version.
    def nano
      self[:nano]
    end

    # Library release candidate suffix string, e.g. "-rc4".
    def rc
      self[:rc].read_string
    end

    # For ABI compatibility only.
    def describe
      self[:describe].read_string
    end

    # Version string, e.g. "1.2.3-rc4"
    def to_s
      "#{major}.#{minor}.#{micro}#{rc}"
    end

    def inspect
      "\#<#{self.class} #{to_s}>"
    end
  end
end
