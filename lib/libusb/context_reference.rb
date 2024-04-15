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

module LIBUSB
  module ContextReference
    def register_context(ctx, free_sym)
      ptr = pointer
      def ptr.free_struct(id)
        return unless @ctx
        Call.send(@free_sym, self)
        @ctx.unref_context
      end
      ptr.instance_variable_set(:@free_sym, free_sym)
      ptr.instance_variable_set(:@ctx, ctx.ref_context)
      ObjectSpace.define_finalizer(self, ptr.method(:free_struct))
    end

    def free
      ptr = pointer
      ptr.free_struct nil
      ptr.instance_variable_set(:@ctx, nil)
    end
  end

  private_constant :ContextReference
end
