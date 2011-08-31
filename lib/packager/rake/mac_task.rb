require 'packager/rake/base_task'

module Packager
  module Rake
    class MacTask < BaseTask

      def initialize(*)
        super

        create_bundle_file_task do
          unless RbConfig::CONFIG["target_cpu"] == "universal"
            puts "Please use a universal binary copy of ruby"
            exit 1
          end
        end
        create_lib_file_task
        create_bin_files_task
        create_resource_files_task
        create_make_pkg_task
        create_directory_tasks
        create_distribution_file_task
        create_package_info_file_task
        create_bom_file_task
        create_payload_file_task
        create_pkg_task

        desc "Package for Mac OS X"
        task :pkg => "#{package_name}.pkg"

        desc "Clean and Package for Mac OS X"
        task :clean => [:rm, :pkg]
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
        total_size / 1024
      end

      def ruby_bin_path
        "/usr/local/ruby1.9/bin/ruby -I /usr/local/#{short_package_name}/bundle -r bundler/setup"
      end

      private

        # HELPERS

        def get_details
          @total_size, @num_files = 0, 0

          Dir["#{package_name}/**/*"].each do |file|
            @num_files += 1

            next if File.directory?(file)

            @total_size += File.size(file)
          end
        end

        # TASK DEFINITIONS

        def create_directory_tasks
          directory "#{short_package_name}-pkg/Resources"
          directory "#{short_package_name}-pkg/#{short_package_name}.pkg"
        end

        def create_distribution_file_task
          erb_path = File.join(RESOURCES_PATH, "Distribution.erb")

          file "#{short_package_name}-pkg/Distribution" do
            src = File.read erb_path
            erb = ERB.new(src)

            File.open("#{short_package_name}-pkg/Distribution", "w") do |file|
              file.puts erb.result(binding)
            end
          end
        end

        def create_package_info_file_task
          erb_path = File.join(RESOURCES_PATH, "PackageInfo.erb")

          file "#{short_package_name}-pkg/#{short_package_name}.pkg/PackageInfo" do
            src = File.read erb_path
            erb = ERB.new(src)

            File.open("#{short_package_name}-pkg/#{short_package_name}.pkg/PackageInfo", "w") do |file|
              file.puts erb.result(binding)
            end
          end
        end

        def create_bom_file_task
          file "#{short_package_name}-pkg/#{short_package_name}.pkg/Bom" do
            sh "mkbom -s #{package_name} #{short_package_name}-pkg/#{short_package_name}.pkg/Bom"
          end
        end

        def create_payload_file_task
          file "#{short_package_name}-pkg/#{short_package_name}.pkg/Payload" do
            sh "cd #{package_name} && pax -wz -x cpio . > ../#{short_package_name}-pkg/#{short_package_name}.pkg/Payload"
          end
        end

        def create_pkg_task
          pkg_dependencies = [:make_pkg, "#{short_package_name}-pkg/Resources", "#{short_package_name}-pkg/#{short_package_name}.pkg",
            "#{short_package_name}-pkg/Distribution", "#{short_package_name}-pkg/#{short_package_name}.pkg/Bom",
            "#{short_package_name}-pkg/#{short_package_name}.pkg/PackageInfo", "#{short_package_name}-pkg/#{short_package_name}.pkg/Payload"]

          file "#{package_name}.pkg" => pkg_dependencies do
            sh "pkgutil --flatten #{short_package_name}-pkg #{package_name}.pkg"

            unless ENV['NOCLEAN']
              # Cleanup
              rm_rf package_name
              rm_rf "#{short_package_name}-pkg"
            end
          end
        end
    end
  end
end
