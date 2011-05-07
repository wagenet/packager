require 'rake'
require 'rake/tasklib'
require 'bundler/setup'
require 'erb'

module Packager
  class RakeTask < ::Rake::TaskLib

    # Name of task.
    #
    # default:
    #   :pkg
    attr_accessor :name

    # Namespace for tasks.
    #
    # default:
    #   :packager
    attr_accessor :group

    attr_accessor :version

    attr_accessor :package_name

    attr_accessor :short_package_name

    attr_accessor :domain

    attr_accessor :bin_files

    def initialize(name=:pkg)
      @name = name
      @group = :packager
      @domain = 'gemcutter.org'
      @bin_files = []
      @package_name, @short_package_name = nil

      yield self if block_given?

      @short_package_name ||= package_name.downcase.gsub(/\W+/,'-')

      namespace group
        bundle_file_task
        lib_file_task
        bin_file_task
        make_pkg_task
        rm_task
        directory_tasks
        distribution_file_task
        package_info_file_task
        bom_file_task
        payload_file_task
        pkg_task

        task :pkg => "#{package_name}.pkg"
        task :clean => [:rm, :pkg]
      end

      desc "Package for Mac OS X"
      task name => "#{group}/pkg"
    end

    def reverse_domain
      @reverse_domain ||= domain.split(".").reverse.join(".")
    end

    def total_size
      get_details unless @total_size
      @total_size
    end

    def num_files
      get_details unless @num_files
      @num_files
    end

    def kbytes
      @total_size / 1024
    end

    private

      # HELPERS

      def pkg_dependencies
        [:make_pkg, "#{package_name}-pkg/Resources", "#{package_name}-pkg/#{package_name}.pkg",
          "#{package_name}-pkg/Distribution", "#{package_name}-pkg/#{package_name}.pkg/Bom",
          "#{package_name}-pkg/#{package_name}.pkg/PackageInfo", "#{package_name}-pkg/#{package_name}.pkg/Payload"]
      end

      def get_details
        @total_size, @num_files = 0, 0

        Dir["#{package_name}/**/*"].each do |file|
          @num_files += 1

          next if File.directory?(file)

          @total_size += File.size(file)
        end
      end

      # TASK DEFINITIONS

      def bundle_file_task
        file "#{package_name}/local/#{short_package_name}/bundle" => "Gemfile" do
          require "rbconfig"

          unless Config::CONFIG["target_cpu"] == "universal"
            puts "Please use a universal binary copy of ruby"
            exit 1
          end

          unless RUBY_VERSION == "1.9.2"
            puts "Please use Ruby 1.9.2"
            exit 1
          end

          puts "Regenerating the bundle."

          sh "rm -rf bundle"
          sh "rm -rf .bundle"
          sh "rm -rf #{short_package_name}-pkg"
          sh "rm -f #{package_name}.pkg"
          Bundler.with_clean_env do
            sh "bundle --standalone --without development"
          end
          sh "mkdir -p #{package_name}/local/#{short_package_name}"
          sh "cp -R bundle #{package_name}/local/#{short_package_name}/"

          verbose(false) do
            Dir.chdir("#{package_name}/local/#{short_package_name}/bundle/ruby/1.9.1") do
              Dir["{bin,cache,doc,specifications}"].each { |f| rm_rf f }
              Dir["**/{ext,docs,test,spec}"].each { |f| rm_rf(f) if File.directory?(f) && f !~ /maruku/i }
              Dir["**/erubis-*/doc-api"].each {|f| rm_rf(f) }
            end
          end
        end
      end

      def lib_file_task
        file "#{package_name}/local/#{short_package_name}/lib"

        `git ls-files -- lib`.split("\n").each do |file|
          dest = "#{package_name}/local/#{short_package_name}/#{file}"
          file dest => file do
            verbose(false) { mkdir_p File.dirname(dest) }
            cp_r file, dest
          end
          task "#{package_name}/local/#{short_package_name}/lib" => dest
        end
      end

      def bin_file_task
        for bin_name in bin_files
          file "#{package_name}/bin/#{bin_name}" => "bin/#{bin_name}" do
            binary = File.read("bin/#{bin_name}").sub(/\A#.*/, "#!/usr/local/ruby1.9/bin/ruby -I /usr/local/#{short_package_name}/bundle -r bundler/setup")

            sh "mkdir -p #{package_name}/bin"
            File.open("#{package_name}/bin/#{bin_name}", "w") { |file| file.puts binary }
            File.chmod 0755, "#{package_name}/bin/#{bin_name}"
          end
        end
      end

      def make_pkg_task
        pkg_tasks = ["#{package_name}/local/#{short_package_name}/bundle",
                           "#{package_name}/local/#{short_package_name}/lib"]
        pkg_tasks += bin_files.map{|b| "#{package_name}/bin/#{b}" }

        desc "Prep the release for PackageMaker"
        task :make_pkg => pkg_tasks
      end

      def rm_task
        task :rm do
          rm_rf package_name
        end
      end

      def directory_tasks
        directory "#{short_package_name}-pkg/Resources"
        directory "#{short_package_name}-pkg/#{short_package_name}.pkg"
      end

      def distribution_file_task
        file "#{short_package_name}-pkg/Distribution" do
          src = File.read File.expand_path("../build/Distribution.erb", __FILE__)
          erb = ERB.new(src)

          File.open("#{short_package_name}-pkg/Distribution", "w") do |file|
            file.puts erb.result(binding)
          end
        end
      end

      def package_info_file_task
        file "#{short_package_name}-pkg/#{short_package_name}.pkg/PackageInfo" do
          src = File.read File.expand_path("../build/PackageInfo.erb", __FILE__)
          erb = ERB.new(src)

          File.open("#{short_package_name}-pkg/#{short_package_name}.pkg/PackageInfo", "w") do |file|
            file.puts erb.result(binding)
          end
        end
      end

      def bom_file_task
        file "#{short_package_name}-pkg/#{short_package_name}.pkg/Bom" do
          sh "mkbom -s #{package_name} #{short_package_name}-pkg/#{short_package_name}.pkg/Bom"
        end
      end

      def payload_file_task
        file "#{short_package_name}-pkg/#{short_package_name}.pkg/Payload" do
          sh "cd #{package_name} && pax -wz -x cpio . > ../#{short_package_name}-pkg/#{short_package_name}.pkg/Payload"
        end
      end

      def pkg_task
        file "#{package_name}.pkg" => pkg_dependencies do
          sh "pkgutil --flatten #{short_package_name}-pkg #{package_name}.pkg"
        end
      end

    end

  end
end
