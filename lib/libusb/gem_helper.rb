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

require "bundler/gem_helper"

module LIBUSB
  class GemHelper < Bundler::GemHelper
    attr_accessor :cross_platforms

    def install
      super

      task "release:guard_clean" => ["release:update_history"]

      task "release:update_history" do
        update_history
      end

      task "release:rubygem_push" => ["gem:native"]
    end

    def hfile
      "History.md"
    end

    def headline
      '([^\w]*)(\d+\.\d+\.\d+)([^\w]+)([2Y][0Y][0-9Y][0-9Y]-[0-1M][0-9M]-[0-3D][0-9D])([^\w]*|$)'
    end

    def reldate
      Time.now.strftime("%Y-%m-%d")
    end

    def update_history
      hin = File.read(hfile)
      hout = hin.sub(/#{headline}/) do
        raise "#{hfile} isn't up-to-date for version #{version}" unless $2==version.to_s
        $1 + $2 + $3 + reldate + $5
      end
      if hout != hin
        Bundler.ui.confirm "Updating #{hfile} for release."
        File.write(hfile, hout)
        Rake::FileUtilsExt.sh "git", "commit", hfile, "-m", "Update release date in #{hfile}"
      end
    end

    def tag_version
      Bundler.ui.confirm "Tag release with annotation:"
      m = File.read(hfile).match(/(?<annotation>#{headline}.*?)#{headline}/m) || raise("Unable to find release notes in #{hfile}")
      Bundler.ui.info(m[:annotation].gsub(/^/, "    "))
      IO.popen(["git", "tag", "--file=-", version_tag], "w") do |fd|
        fd.write m[:annotation]
      end
      yield if block_given?
    rescue
      Bundler.ui.error "Untagging #{version_tag} due to error."
      sh_with_code "git tag -d #{version_tag}"
      raise
    end

    def rubygem_push(path)
      cross_platforms.each do |ruby_platform|
        super(path.gsub(/\.gem\z/, "-#{ruby_platform}.gem"))
      end
      super(path)
    end
  end


  class CrossLibrary < OpenStruct
    include Rake::DSL

    def initialize(ruby_platform, host_platform, libusb_dllname)
      super()

      self.ruby_platform = ruby_platform
      self.recipe = LIBUSB::LibusbRecipe.new
      recipe.host = ruby_platform
      recipe.configure_options << "--host=#{host_platform}"
      recipe.configure_options << "CC=#{host_platform}-gcc -static-libgcc" if recipe.host =~ /mingw/
      self.libusb_dll = Pathname.new(recipe.path) + libusb_dllname

      file libusb_dll do
        recipe.cook
      end

      task "libusb_dll:#{ruby_platform}" => libusb_dll

      desc 'Cross compile libusb for all targets'
      task :cross => "cross:#{ruby_platform}"

      desc "Cross compile libusb for #{ruby_platform}"
      task "cross:#{ruby_platform}" => [ "libusb_dll:#{ruby_platform}" ] do |t|
        spec = Gem::Specification::load("libusb.gemspec").dup
        spec.platform = Gem::Platform.new(ruby_platform)
        spec.extensions = []

        # Remove files unnecessary for native gems
        spec.files -= `git ls-files ext`.split("\n")
        spec.files.reject!{|f| f.start_with?('ports') }
        spec_text_files = spec.files.dup

        # Add native libusb-dll
        spec.files << "lib/#{libusb_dll.basename}"

        # MiniPortile isn't required for native gems
        spec.dependencies.reject!{|d| d.name=="mini_portile2" }

        # Generate a package for this gem
        pkg = Gem::PackageTask.new(spec) do |pkg|
          pkg.need_zip = false
          pkg.need_tar = false
          # Do not copy any files per PackageTask, because
          # we need the files from the platform specific directory
          pkg.package_files.clear
        end

        # copy files of the gem to pkg directory
        file pkg.package_dir_path => spec_text_files do
          spec_text_files.each do |fn|
            f = File.join(pkg.package_dir_path, fn)
            fdir = File.dirname(f)
            mkdir_p(fdir) if !File.exist?(fdir)
            rm_f f
            safe_ln(fn, f)
          end

          # copy libusb.dll to pkg directory
          f = "#{pkg.package_dir_path}/lib/#{libusb_dll.basename}"
          mkdir_p File.dirname(f)
          rm_f f
          safe_ln libusb_dll.realpath, f
        end

        file "lib/#{libusb_dll.basename}" => [libusb_dll]
      end
    end
  end
end
