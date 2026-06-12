# frozen_string_literal: true

require 'logger'

module Nightshift
  #
  # Log — Structured logger
  #
  # Thin wrapper over Ruby's Logger with timestamp-prefixed output
  # to stdout. Severity controlled via NIGHTSHIFT_LOG_LEVEL env var.
  #
  module Log
    extend T::Sig
    module_function

    def logger
      @logger ||= build_logger
    end

    sig { params(msg: String).void }
    def info(msg) = logger.info(msg)

    sig { params(msg: String).void }
    def warn(msg) = logger.warn(msg)

    sig { params(msg: String).void }
    def error(msg) = logger.error(msg)

    sig { params(msg: String).void }
    def debug(msg) = logger.debug(msg)

    private

    def build_logger
      l = ::Logger.new($stdout)
      l.level = ENV.fetch('NIGHTSHIFT_LOG_LEVEL', 'INFO')
      l.formatter = method(:format_line)
      l
    end
    module_function :build_logger

    def format_line(severity, time, _progname, msg)
      ts = time.strftime('%H:%M:%S')
      case severity
      when 'INFO'  then "#{ts} #{msg}\n"
      when 'DEBUG' then "#{ts} [DBG] #{msg}\n"
      when 'WARN'  then "#{ts} [WARN] #{msg}\n"
      when 'ERROR' then "#{ts} [ERROR] #{msg}\n"
      else              "#{ts} [#{severity}] #{msg}\n"
      end
    end
    module_function :format_line
  end
end
