Matrix SSE
==========

A small testbed server for trying out [MSC2108][1] for the [Matrix protocol][2]

## Installation

Check out this repo, install the bundle, instantiate the config, and run `matrix_sse` to launch the server.

An example configuration is provided as;
```json
{
    "homeserver": "https://matrix.org",
    "default_heartbeat": 5
}
```

## Usage

When the server is running, any requests to `/_matrix/client/r0/sync/sse` will
launch an SSE stream, taking the same parameters as the upstream
[sync request][3]. Except for `interval` and `since` as mentioned in the
[MSC][1].

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ananace/matrix_sse

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

[1]: https://github.com/matrix-org/matrix-doc/pull/2108
[2]: https://matrix.org
[3]: https://matrix.org/docs/spec/client_server/latest#get-matrix-client-r0-sync
