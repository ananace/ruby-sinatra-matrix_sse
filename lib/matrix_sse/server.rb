# frozen_string_literal: true

require 'matrix_sdk'

module MatrixSse
  class Server
    attr_accessor :logger, :default_heartbeat

    def initialize(hs_url, logger: nil)
      @main_api = MatrixSdk::Api.new hs_url
      @connections = []
      @default_heartbeat = 5
      @logger = logger
    end

    def add_connection(conn)
      conn.api = MatrixSdk::Api.new(
        @main_api.homeserver,
        access_token: conn.access_token
      )
      conn.heartbeat_interval ||= default_heartbeat
      conn.logger = logger

      logger.info "Server: Adding connection #{conn.name}"
      @connections << conn
    end

    def remove_connection(conn)
      logger.info "Server: Removing connection #{conn.name}"
      conn.reset_query
      @connections.delete conn
    end

    def start_background_worker
      @background_running = true
      @background_thread = Thread.new { background_thread }
    end

    def stop_background_worker
      @background_running = false
      @background_thread.join
    end

    private

    def background_thread
      loop do
        return unless @background_running

        @connections.each do |conn|
          conn.send_comment('heartbeat') if conn.heartbeat_required?

          query = conn.query
          next if query.incomplete?

          if query.rejected?
            err = query.reason

            conn.send_event name: :sync_error, data: err
          else
            data = query.value

            id = data.next_batch
            data.delete :next_batch
            conn.since = id

            conn.send_data data, id: id
          end

          conn.reset_query
          conn.query
        end

        sleep 0.5
      end
    end
  end
end
