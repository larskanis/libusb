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
  require 'libusb/call'
  require 'libusb/constants'
  require 'libusb/context'
  autoload :VERSION, 'libusb/version_gem'
  autoload :Version, 'libusb/version_struct'
  autoload :Configuration, 'libusb/configuration'
  autoload :DevHandle, 'libusb/dev_handle'
  autoload :Device, 'libusb/device'
  autoload :Endpoint, 'libusb/endpoint'
  autoload :Interface, 'libusb/interface'
  autoload :Setting, 'libusb/setting'
  autoload :SsCompanion, 'libusb/ss_companion'
  autoload :Stdio, 'libusb/stdio'
  autoload :Bos, 'libusb/bos'
  %w[ Transfer BulkTransfer BulkStreamTransfer ControlTransfer InterruptTransfer IsoPacket IsochronousTransfer ].each do |klass|
    autoload klass, 'libusb/transfer'
  end

  class << self
    if Call.respond_to?(:libusb_get_version)
      # Get version of the underlying libusb library.
      # Available since libusb-1.0.10.
      # @return [Version]  version object
      def version
        Version.new(Call.libusb_get_version)
      end
    end

    if Call.respond_to?(:libusb_has_capability)
      # Check at runtime if the loaded library has a given capability.
      # Available since libusb-1.0.9.
      # @param [Symbol] capability  the {Call::Capabilities Capabilities} symbol to check for
      # @return [Boolean]  +true+ if the running library has the capability, +false+ otherwise
      def has_capability?(capability)
        r = Call.libusb_has_capability(capability)
        return r != 0
      end
    else
      def has_capability?(capability)
        false
      end
    end

    private def expect_option_args(exp, is)
      raise ArgumentError, "wrong number of arguments (given #{is+1}, expected #{exp+1})" if is != exp
    end

    private def wrap_log_cb(block, mode)
      cb_proc = proc do |p_ctx, lev, str|
        ctx = case p_ctx
          when FFI::Pointer::NULL then nil
          else p_ctx.to_i
        end
        block.call(ctx, lev, str)
      end

      # Avoid garbage collection of the proc, since only the function pointer is given to libusb
      if Call::LogCbMode.to_native(mode, nil) & LOG_CB_GLOBAL != 0
        @log_cb_global_proc = cb_proc
      end
      if Call::LogCbMode.to_native(mode, nil) & LOG_CB_CONTEXT != 0
        @log_cb_context_proc = cb_proc
      end
    end

    private def option_args_to_ffi(option, args, ctx)
      case option
        when :OPTION_LOG_LEVEL, LIBUSB::OPTION_LOG_LEVEL
          expect_option_args(1, args.length)
          [:libusb_log_level, args[0]]
        when :OPTION_USE_USBDK, LIBUSB::OPTION_USE_USBDK
          expect_option_args(0, args.length)
          []
        when :OPTION_NO_DEVICE_DISCOVERY, LIBUSB::OPTION_NO_DEVICE_DISCOVERY
          expect_option_args(0, args.length)
          []
        when :OPTION_LOG_CB, LIBUSB::OPTION_LOG_CB
          expect_option_args(1, args.length)
          cb_proc = ctx.send(:wrap_log_cb, args[0], LOG_CB_CONTEXT)
          [:libusb_log_cb, cb_proc]
        else
          raise ArgumentError, "unknown option #{option.inspect}"
      end
    end

    if Call.respond_to?(:libusb_set_option)
      # Set an default option in the libusb library.
      #
      # Use this function to configure a specific option within the library.
      # See {Call::Options option list}.
      #
      # Some options require one or more arguments to be provided.
      # Consult each option's documentation for specific requirements.
      #
      # The option will be added to a list of default options that will be applied to all subsequently created contexts.
      #
      # Available since libusb-1.0.22, LIBUSB_API_VERSION >= 0x01000106
      #
      # @param [Symbol, Fixnum] option
      # @param args  Zero or more arguments depending on +option+
      #
      # Available since libusb-1.0.22
      def set_option(option, *args)
        ffi_args = option_args_to_ffi(option, args, self)
        res = Call.libusb_set_option(nil, option, *ffi_args)
        LIBUSB.raise_error res, "in libusb_set_option" if res<0
      end

      # Set default options in the libusb library.
      #
      # Use this function to configure any number of options within the library.
      # It takes a Hash the same way as given to {Context.initialize}.
      # See also {Call::Options option list}.
      #
      # Available since libusb-1.0.22, LIBUSB_API_VERSION >= 0x01000106
      #
      # @param [Hash] options   Kind of: Hash[<{Call::Options}> => <option value(s)>]
      def set_options(options={})
        opts = options.each do |k, v|
          args = LIBUSB.send(:option_args_to_ffi, k, Array(v), self)
          res = Call.libusb_set_option(nil, k, *args)
          LIBUSB.raise_error res, "in libusb_set_option" if res<0
        end
      end
    end
  end
end
