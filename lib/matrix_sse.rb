# frozen_string_literal: true

require 'matrix_sse/version'

module MatrixSse
  class Error < StandardError; end

  autoload :Application, 'matrix_sse/application'
  autoload :Connection, 'matrix_sse/connection'
  autoload :Server, 'matrix_sse/server'
end
