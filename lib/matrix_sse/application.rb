# frozen_string_literal: true

require 'json'
require 'logging'
require 'sinatra/base'

module MatrixSse
  class Application < Sinatra::Base
    attr_reader :config, :sse_server

    def initialize(config)
      super
      @config = config

      @sse_server = MatrixSse::Server.new config['homeserver']
      sse_server.start_background_worker
      sse_server.default_heartbeat = config['default_heartbeat'] if config.key? 'default_heartbeat'
      sse_server.ensure_logger Logging.logger[self]

      verify_hs!
    end

    configure :development do
      require 'sinatra/reloader'
      register Sinatra::Reloader

      Logging.logger[self].tap do |logger|
        logger.add_appenders ::Logging.appenders.stdout
        logger.level = :debug
      end
    end

    options '/_matrix/client/r0/sync/sse', provides: :json do
      {}.to_json
    end

    get '/_matrix/client/r0/sync/sse', provides: 'text/event-stream' do
      pass unless request.accept? 'text/event-stream'

      Logging.logger[self].info "Received SSE request, params: #{params}"

      unless request.has_header? 'HTTP_AUTHORIZATION'
        content_type :json
        halt 401, {
          errcode: 'M_MISSING_TOKEN',
          error: 'Missing authorization header'
        }.to_json
      end

      params = request.params

      stream :keep_open do |out|
        conn = MatrixSse::Connection.new(
          stream: out,
          access_token: request.get_header('HTTP_AUTHORIZATION').gsub('Bearer ', ''),
          concurrent_event: sse_server.event,

          heartbeat_interval: params.fetch('heartbeat_interval', sse_server.default_heartbeat).to_i,
          since: request.get_header('HTTP_LAST_EVENT_ID'),
          filter: params['filter'],
          set_presence: params['set_presence'],
          full_state: params['full_state']
        )

        sse_server.add_connection conn
        out.callback { sse_server.remove_connection(conn) }
      end
    end

    private

    def verify_hs!
      v = sse_server.main_api.client_api_versions
      raise 'Unable to verify HS connection, check if the configured HS is alive' if v.nil? || v.empty?
    rescue StandardError
      raise 'Unable to verify HS connection, check URL'
    end
  end
end
