require_relative 'dependencies'
require 'rubygems'
# Keep the version constraint in sync with libusb.gemspec
gem "mini_portile2", LIBUSB::MINI_PORTILE_VERSION
require "mini_portile2"

module LIBUSB
  class LibusbRecipe < MiniPortile
    ROOT = File.expand_path('../../..', __FILE__)

    def initialize
      super("libusb", LIBUSB_VERSION)
      self.target = File.join(ROOT, "ports")
      self.files = [url: LIBUSB_SOURCE_URI, sha256: LIBUSB_SOURCE_SHA256]
      self.patch_files = Dir[File.join(ROOT, "patches", self.name, self.version, "*.patch")].sort
      self.configure_options = []
    end

    def cook_and_activate
      checkpoint = File.join(self.target, "#{self.name}-#{self.version}-#{self.host}.installed")
      unless File.exist?(checkpoint)
        self.cook
        FileUtils.touch checkpoint
      end
      self.activate
      self
    end

    public :files_hashs


    def execute(action, command, command_opts={})
      opt_message = command_opts.fetch(:initial_message, true)
      opt_debug =   command_opts.fetch(:debug, false)
      opt_cd =      command_opts.fetch(:cd) { work_path }
      opt_env =     command_opts.fetch(:env) { Hash.new }
      opt_altlog =  command_opts.fetch(:altlog, nil)

      log_out = log_file(action)

      Dir.chdir(opt_cd) do
        output "DEBUG: env is #{opt_env.inspect}" if opt_debug
        output "DEBUG: command is #{command.inspect}" if opt_debug
        message "Running '#{action}' for #{@name} #{@version}... " if opt_message

        options = {[:out, :err]=>[log_out, "a"]}
        output "DEBUG: options are #{options.inspect}" if opt_debug
        args = [opt_env, command, options].flatten
        pid = spawn(*args)

        if Process::Status.wait(pid).success?
          output "OK"
          return true
        else
          output "ERROR. Please review logs to see what happened:\n"
          [log_out, opt_altlog].compact.each do |log|
            next unless File.exist?(log)
            output("----- contents of '#{log}' -----")
            output(File.read(log))
            output("----- end of file -----")
          end
          raise "Failed to complete #{action} task"
        end
      end
    end
  end
end
