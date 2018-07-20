require 'google/apis/drive_v3'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'fileutils'

module Backup
  module Storage
    class GoogleDrive < Base
      include Storage::Cycler
      class Error < Backup::Error; end

      OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'.freeze
      APPLICATION_NAME = 'Backup'.freeze

      ##
      # Google API credentials
      attr_accessor :credential_json_path

      ##
      # Path to store cached authorized session.
      #
      # Relative paths will be expanded using Config.root_path,
      # which by default is ~/Backup unless --root-path was used
      # on the command line or set in config.rb.
      #
      # By default, +cache_path+ is '.cache', which would be
      # '~/Backup/.cache/' if using the default root_path.
      attr_accessor :cache_path

      ##
      # Google Access Type
      attr_accessor :access_type

      ##
      # Storing folder id
      attr_accessor :folder_id

      ##
      # Creates a new instance of the storage object
      def initialize(model, storage_id = nil)
        super

        @credential_json_path ||= './'
        @path                 ||= "backups"
        @cache_path           ||= "./.cache"
        @access_type          ||= Google::Apis::DriveV3::AUTH_DRIVE
        @folder_id            ||= ''
        path.sub!(/^\//, "")
      end

      private

      def connection
        service = Google::Apis::DriveV3::DriveService.new
        service.client_options.application_name = APPLICATION_NAME
        service.authorization = authorize
        service
      # rescue => err
      #   raise Error.wrap(err, "Authorization Failed")
      end

      ##
      # Ensure valid credentials, either by restoring from the saved credentials
      # files or intitiating an OAuth2 authorization. If authorization is required,
      # the user's default browser will be launched to approve the request.
      #
      # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
      def authorize
        client_id = Google::Auth::ClientId.from_file(@credential_json_path)
        token_store = Google::Auth::Stores::FileTokenStore.new(file: "#{@cache_path}/token.yaml")
        authorizer = Google::Auth::UserAuthorizer.new(client_id, @access_type, token_store)
        user_id = 'default'
        credentials = authorizer.get_credentials(user_id)
        if credentials.nil?
          url = authorizer.get_authorization_url(base_url: OOB_URI)
          puts 'Open the following URL in the browser and enter the ' \
           "resulting code after authorization:\n" + url
          puts 'Enter obtained code here:'
          code = $stdin.gets.chomp
          credentials = authorizer.get_and_store_credentials_from_code(
              user_id: user_id, code: code, base_url: OOB_URI
          )
        end
        credentials
      end

      def transfer!
        service = connection
        package.filenames.each do |filename|
          src = File.join(Config.tmp_path, filename)
          Logger.info "Storing '#{src} to GoogleDrive..."
          md = Google::Apis::DriveV3::File.new(name: "#{Time.now.strftime('%Y%m%dT%H%M')}_#{filename}",
                                               parents: [ @folder_id ])
          service.create_file(md, upload_source: src)
        end
      end

      # Called by the Cycler.
      # Any error raised will be logged as a warning.
      def remove!(package)
        raise NotImplementedError
      end


    end
  end
end
