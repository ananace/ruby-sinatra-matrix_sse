# frozen_string_literal: true

require 'concurrent'
require 'matrix_sdk'

module MatrixSse
  class Server
    attr_accessor :logger, :default_heartbeat
    attr_reader :event, :main_api

    def initialize(hs_url, logger: nil)
      @main_api = MatrixSdk::Api.new hs_url
      @connections = []
      @default_heartbeat = 5
      @logger = logger

      @event = Concurrent::Event.new
    end

    # TODO: Avoid the necessity of this
    def ensure_logger(logger)
      @logger ||= logger
    end

    def add_connection(conn)
      conn.api = MatrixSdk::Api.new(
        @main_api.homeserver,
        access_token: conn.access_token,
      )
      conn.heartbeat_interval ||= default_heartbeat
      conn.logger = logger

      logger.info "Server: Adding connection #{conn.name}"
      @connections << conn

      @event.set
    end

    def remove_connection(conn)
      logger.info "Server: Removing connection #{conn.name}"
      conn.reset_query
      @connections.delete conn
    end

    def start_background_worker
      @background_running = true
      @background_thread = Thread.new { background_thread }
      @heartbeat_thread = Thread.new { heartbeat_thread }
    end

    def stop_background_worker
      @background_running = false
      @event.set
      @heartbeat_thread.join
      @background_thread.join
    end

    private

    def heartbeat_thread
      loop do
        return unless @background_running

        @connections.each do |conn|
          conn.send_comment('heartbeat') if conn.heartbeat_required?
        end

        sleep 0.5
      end
    end

    def background_thread
      loop do
        @event.wait
        @event.reset

        return unless @background_running

        # TODO: Avoid iterating all connections for every result
        @connections.each do |conn|
          begin
            query = conn.query
            next if query.incomplete?

            if query.rejected?
              err = query.reason

              conn.send_event name: :sync_error, data: {
                type: err.class,
                message: err.message,
                trace: err.backtrace
              }.to_json
            else
              data = query.value

              id = data.next_batch
              data.delete :next_batch
              conn.since = id

              conn.send_data data, id: id if conn.wants? data
            end

            conn.reset_query
            conn.query
          rescue StandardError => e
            logger.error "#{e.class} occurred for connection #{conn.name}, skipping;\n#{e.full_message}" # rubocop:disable Layout/LineLength
          end
        end
      end
    end
  end
end
