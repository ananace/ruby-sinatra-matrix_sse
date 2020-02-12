# frozen_string_literal: true

require 'concurrent'

module MatrixSse
  class Connection
    attr_accessor :api, :filter, :full_state, :heartbeat_interval,
                  :last_heartbeat, :logger, :name, :set_presence, :since
    attr_reader :access_token, :stream

    def initialize(stream:, access_token:, event:, **params)
      @stream = stream
      @access_token = access_token
      @event = event

      @write_lock = Mutex.new
      @clean_events = false

      @heartbeat_interval = params[:heartbeat_interval]
      @since = params[:since]
      @filter = params[:filter]
      @name = params[:name] || object_id.to_s(16)
      @set_presence = params[:set_presence]
      @full_state = params[:full_state]

      @logger = params[:logger]
      @last_send = Time.now
    end

    def heartbeat_required?
      (Time.now - @last_send) > (heartbeat_interval || 5)
    end

    def send_comment(comment = nil)
      @write_lock.lock
      logger.info "Conn|#{name}: Sending comment \"#{comment}\""
      stream << ": #{comment}\n\n"
      @last_send = Time.now
    ensure
      @write_lock.unlock
    end

    def send_data(data, id: nil)
      data = clean_sync(data) if @clean_events

      send_event(name: :sync, data: data.to_json, id: id)
    end

    def send_event(name:, data:, id: nil)
      @write_lock.lock
      logger.info "Conn|#{self.name}: Sending event '#{name}' with #{data.size}B of data"
      stream << "event: #{name}\n"
      stream << "id: #{id}\n" if id
      stream << "data: #{data.split("\n").join("\ndata: ")}\n\n"
      @last_send = Time.now
    ensure
      @write_lock.unlock
    end

    def query
      @query ||= Concurrent::Future.execute do
        begin
          params = {
            since: since,
            filter: filter,
            full_state: full_state,
            set_presence: set_presence
          }.compact

          logger.info "Conn|#{name}: Starting query with params #{params.to_json}"

          api.sync(**params)
        ensure
          @event.set
        end
      end
    end

    def reset_query
      @query&.cancel
      @query = nil
    end

    private 

    def clean_sync(data)
      # Remove empty main-level keys
      data.reject! { |_, v| v.nil? || ((v.is_a?(Array) || v.is_a?(Hash)) && v.empty?) }

      # Remove empty rooms keys (join/leave/invite)
      data['rooms'].reject! { |_, v| v.nil? || ((v.is_a?(Array) || v.is_a?(Hash)) && v.empty?) }

      # Remove empty room-level keys (rooms->join->!room:example.com-> state/timeline/ephemeral/account_data)
      data['rooms'].each { |_, v| v.each { |_, r| r.reject! { |_k, v| v.nil? || ((v.is_a?(Array) || v.is_a?(Hash)) && v.empty?) } } }
    end
  end
end

# {
#   "next_batch": "s72595_4483_1934",
#   "presence": {
#     "events": [
#       {
#         "content": {
#           "avatar_url": "mxc://localhost:wefuiwegh8742w",
#           "last_active_ago": 2478593,
#           "presence": "online",
#           "currently_active": false,
#           "status_msg": "Making cupcakes"
#         },
#         "type": "m.presence",
#         "sender": "@example:localhost"
#       }
#     ]
#   },
#   "account_data": {
#     "events": [
#       {
#         "type": "org.example.custom.config",
#         "content": {
#           "custom_config_key": "custom_config_value"
#         }
#       }
#     ]
#   },
#   "rooms": {
#     "join": {
#       "!726s6s6q:example.com": {
#         "summary": {
#           "m.heroes": [
#             "@alice:example.com",
#             "@bob:example.com"
#           ],
#           "m.joined_member_count": 2,
#           "m.invited_member_count": 0
#         },
#         "state": {
#           "events": [
#             {
#               "content": {
#                 "membership": "join",
#                 "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
#                 "displayname": "Alice Margatroid"
#               },
#               "type": "m.room.member",
#               "event_id": "$143273582443PhrSn:example.org",
#               "room_id": "!726s6s6q:example.com",
#               "sender": "@example:example.org",
#               "origin_server_ts": 1432735824653,
#               "unsigned": {
#                 "age": 1234
#               },
#               "state_key": "@alice:example.org"
#             }
#           ]
#         },
#         "timeline": {
#           "events": [
#             {
#               "content": {
#                 "membership": "join",
#                 "avatar_url": "mxc://example.org/SEsfnsuifSDFSSEF",
#                 "displayname": "Alice Margatroid"
#               },
#               "type": "m.room.member",
#               "event_id": "$143273582443PhrSn:example.org",
#               "room_id": "!726s6s6q:example.com",
#               "sender": "@example:example.org",
#               "origin_server_ts": 1432735824653,
#               "unsigned": {
#                 "age": 1234
#               },
#               "state_key": "@alice:example.org"
#             },
#             {
#               "content": {
#                 "body": "This is an example text message",
#                 "msgtype": "m.text",
#                 "format": "org.matrix.custom.html",
#                 "formatted_body": "<b>This is an example text message</b>"
#               },
#               "type": "m.room.message",
#               "event_id": "$143273582443PhrSn:example.org",
#               "room_id": "!726s6s6q:example.com",
#               "sender": "@example:example.org",
#               "origin_server_ts": 1432735824653,
#               "unsigned": {
#                 "age": 1234
#               }
#             }
#           ],
#           "limited": true,
#           "prev_batch": "t34-23535_0_0"
#         },
#         "ephemeral": {
#           "events": [
#             {
#               "content": {
#                 "user_ids": [
#                   "@alice:matrix.org",
#                   "@bob:example.com"
#                 ]
#               },
#               "type": "m.typing",
#               "room_id": "!jEsUZKDJdhlrceRyVU:example.org"
#             }
#           ]
#         },
#         "account_data": {
#           "events": [
#             {
#               "content": {
#                 "tags": {
#                   "u.work": {
#                     "order": 0.9
#                   }
#                 }
#               },
#               "type": "m.tag"
#             },
#             {
#               "type": "org.example.custom.room.config",
#               "content": {
#                 "custom_config_key": "custom_config_value"
#               }
#             }
#           ]
#         }
#       }
#     },
#     "invite": {
#       "!696r7674:example.com": {
#         "invite_state": {
#           "events": [
#             {
#               "sender": "@alice:example.com",
#               "type": "m.room.name",
#               "state_key": "",
#               "content": {
#                 "name": "My Room Name"
#               }
#             },
#             {
#               "sender": "@alice:example.com",
#               "type": "m.room.member",
#               "state_key": "@bob:example.com",
#               "content": {
#                 "membership": "invite"
#               }
#             }
#           ]
#         }
#       }
#     },
#     "leave": {}
#   }
# }
