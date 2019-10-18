# frozen_string_literal: true

require 'concurrent'

module MatrixSse
  class Connection
    attr_accessor :api, :filter, :full_state, :heartbeat_interval,
                  :last_heartbeat, :logger, :name, :set_presence, :since, :sse2
    attr_reader :access_token, :stream

    def initialize(stream:, access_token:, **params)
      @stream = stream
      @access_token = access_token

      @heartbeat_interval = params[:heartbeat_interval]
      @since = params[:since]
      @filter = params[:filter]
      @name = params[:name] || object_id.to_s(16)
      @set_presence = params[:set_presence]
      @full_state = params[:full_state]
      @sse2 = params[:sse2]

      @logger = params[:logger]
      @last_send = Time.now
    end

    def heartbeat_required?
      (Time.now - @last_send) > (heartbeat_interval || 5)
    end

    def send_comment(comment = nil)
      logger.info "Conn|#{name}: Sending comment \"#{comment}\""
      stream << ": #{comment}\n\n"
      @last_send = Time.now
    end

    def send_data(data, id: nil)
      if sse2
        data.keys.each do |key|
          data[key].each do |value|
            send_event(name: key, data: value.to_json, id: id)
          end
        end
      else
        send_event(name: :sync, data: data, id: id)
      end
    end

    def send_event(name:, data:, id: nil)
      logger.info "Conn|#{self.name}: Sending event '#{name}' with #{data.size}B of data"
      stream << "event: #{name}\n"
      stream << "id: #{id}\n" if id
      stream << "data: #{data}\n\n"
      @last_send = Time.now
    end

    def query
      @query ||= Concurrent::Future.execute do
        params = {
          since: since,
          filter: filter,
          full_state: full_state,
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
