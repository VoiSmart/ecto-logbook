import Config

config :logger, :level, :debug
config :logbook, :default_tag_level, :debug
config :logger, :default_formatter, format: {Logbook.Formatters.Logfmt, :format}, metadata: :all
