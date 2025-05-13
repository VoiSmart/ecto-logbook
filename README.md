# EctoLogbook

An alternative logger for Ecto queries that uses [Logbook](https://hex.pm/packages/logbook).

This package aims at making Ecto logs readable when used with a logfmt formatter.

Read the docs at [https://voismart.github.io/ecto-logbook/](https://voismart.github.io/ecto-logbook/).

Features:

- Uses log metadata that can be parsed if using a logfmt/json formatter.
- Uses [Logbook](https://hex.pm/packages/logbook) for logging, making it easy to enable/disable logging
- With `:colorize` option, Highlights db time for slow queries
- With `:inline_params` option, tries to inline parameters into the query
- If repo `:stacktrace` is enabled, MFA information will be included in the log metadata

The base of this project is a fork of https://github.com/fuelen/ecto_dev_logger
Differently from the original project, this package doesn't try hard to print valid queries.
Instead it just aims for readability of the logs.

## Installation

The package can be installed by adding `ecto_logbook` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_logbook, git: "https://github.com/voismart/ecto_logbook.git", tag: "v1.14.3"}
  ]
end
```

## Configuration

Configure your logger in `config.exs`:

```elixir
import Config

# EctoLogbook will log at debug level
config :logger, :level, :debug
config :logbook, :default_tag_level, :debug

# Use a logfmt formatter and display all metadata
config :logger, :default_formatter, format: {Logbook.Formatters.Logfmt, :format}, metadata: :all
```

In order to use EctoLogbook, you should disable youe Repo default logs.

```elixir
config :my_app, MyApp.Repo, log: false
```

Then install telemetry handler in `MyApp.Application`:

```elixir
EctoLogbook.install(MyApp.Repo)
```

```diff
- Telemetry handler will be installed _only_ if `log` configuration value is set to `false`.
```

You can then finetune the logging level for EctoLogbook using `Logbook.set_level/2`:

```elixir
# Disable logging for EctoLogbook
Logbook.set_level(:ecto_logbook, :none)

# Enable logging for EctoLogbook
Logbook.set_level(:ecto_logbook, :debug)
```

For more configuration options, see [Logbook](https://hexdocs.pm/logbook/Logbook.html).

### Display Options

By default EctoLogbook will try to do as little transformation as possible to make logging fast.
You can pass options to `EctoLogbook.install/2` to fine tune the display behavior:

```elixir
EctoLogbook.install(MyApp.Repo,
  colorize: true, # Use colors to highlight queries, parameters and db time
  inline_params: true, # Try to inline parameters in the query
  log_repo_name: true, # Log repo name (useful if multiple repos are used)
  preprocess_metadata_callback: fn metadata -> metadata end,
  ignore_event_callback: fn metadata -> !String.match(metadata[:query], ~r/SELECT/)  end
)
```

See `EctoLogbook.install/2` for the full doc.

### Display stacktrace info

If the repo `:stacktrace` configuration is set to `true`, MFA information will be included in the log metadata.

```elixir
config :my_app, MyApp.Repo, log: false, stacktrace: true
```
