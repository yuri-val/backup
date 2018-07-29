require "rmega"

module Backup
  module Storage
    class Mega < Base
      include Storage::Cycler
      class Error < Backup::Error; end
      # Credentials
      attr_accessor :login, :password
      # Storing folder id
      attr_accessor :path_name
      # Storage
      attr_accessor :storage

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super
        @path_name ||= ''
        raise Error.wrap("No credentials") unless @login || @password
        connect!
      end

      private

      def connect!
        @storage = Rmega.login(@login, @password)
      rescue => err
        raise Error.wrap(err, "Authorization Failed")
      end

      def transfer!
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          Logger.info "Storing '#{src} to #{self.class}..."
          folder.upload(src)
        end
      end

      def folder
        current_folder = @storage.root
        return current_folder if @path_name.empty? || @path_name == '/'
        folders = @path_name.split '/'
        folders.each do |p_folder|
          c_folder = current_folder.nodes.find do |node|
            node.type == :folder && node.name == p_folder
          end
          current_folder = c_folder || current_folder.create_folder(p_folder)
        end
        current_folder
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        raise NotImplementedError
      end


    end
  end
end