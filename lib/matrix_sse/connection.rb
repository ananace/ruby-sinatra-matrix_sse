# frozen_string_literal: true

require 'concurrent'

module MatrixSse
  class Connection
    attr_accessor :api, :filter, :heartbeat_interval, :last_heartbeat, :logger,
                  :name, :set_presence, :since
    attr_reader :access_token, :stream

    def initialize(stream:, access_token:, **params)
      @stream = stream
      @access_token = access_token

      @heartbeat_interval = params[:heartbeat_interval] || 5
      @since = params[:since]
      @filter = params[:filter]
      @name = params[:name] || object_id.to_s(16)
      @set_presence = params[:set_presence]

      @logger = params[:logger]
      @last_send = Time.now
    end

    def heartbeat_required?
      (Time.now - @last_send) > heartbeat_interval
    end

    def send_comment(comment = nil)
      logger.info "Conn|#{name}: Sending comment \"#{comment}\""
      stream << ": #{comment}\n\n"
      @last_send = Time.now
    end

    def send_error(err)
      logger.info "Conn|#{name}: Sending error #{err}"
      stream << "event: sync_error\n"
      stream << "data: #{err}\n\n"
      @last_send = Time.now
    end

    def send_data(data, id: nil)
      logger.info "Conn|#{name}: Sending #{data.size}B of data"
      stream << "event: sync\n"
      stream << "id: #{id}\n" if id
      stream << "data: #{data}\n\n"
      @last_send = Time.now
    end

    def query
      @query ||= Concurrent::Future.execute do
        params = {
          since: since,
          filter: filter,
          set_presence: set_presence
        }.compact

        logger.info "Conn|#{name}: Starting query with params #{params.to_json}"

        api.sync(**params)
      end
    end

    def reset_query
      @query&.cancel
      @query = nil
    end
  end
end
