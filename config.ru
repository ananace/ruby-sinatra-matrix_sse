# frozen_string_literal: true

raise 'config.json is missing, please create one before running.' unless File.exist? 'config.json'

require 'json'
require 'matrix_sse'

config = JSON.parse(File.read('config.json'))

map '/health' do
  run ->(_env) { ['200', { 'Content-Type' => 'text/plain' }, ['OK']] }
end

run MatrixSse::Application.new config
