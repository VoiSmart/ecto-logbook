defmodule Ecto.DevLogger do
  @moduledoc """
  An alternative logger for Ecto queries.

  A fork of https://github.com/fuelen/ecto_dev_logger

  It inlines bindings into the query, so it is easy to copy-paste logged SQL and run it in any IDE for debugging without
  manual transformation of common elixir terms to string representation (binary UUID, DateTime, Decimal, json, etc).
  Also, it highlights db time to make slow queries noticeable. Source table and inlined bindings are highlighted as well.
  """

  require Logbook
  @logbook_tag :ecto_logbook
  @reset_color IO.ANSI.cyan()

  @typedoc """
  Options for `install/2`
  """
  @type option ::
          {:colorize, boolean()}
          | {:inline_params, boolean()}
          | {:log_repo_name, boolean()}
          | {:ignore_event_callback, (metadata :: map() -> boolean())}
          | {:before_inline_callback, (query :: String.t() -> String.t())}
          | {:debug_telemetry_metadata, boolean()}

  @doc """
  Attaches `telemetry_handler/4` to application.

  Returns the result from the call to `:telemetry.attach/4` or `:ok` if the repo has default logging enabled.

  ## Options

  * `:colorize` - if true __MODULE__.colors will be applied to logs.
  * `:inline_params` - if true query params will be substituted and inlined in log message.
  * `:log_repo_name` - when truthy will add the repo name into the log.
  * `:ignore_event_callback` - allows to skip telemetry events. see `ignore_event/1`
  * `:before_inline_callback` - allows to modify the query before inlining of bindings. see `before_inline/1`
  * `:debug_telemetry_metadata` - for debugging purposes, if true also logs all telemetry metadata.
  """
  @spec install(repo_module :: module(), opts :: [option()]) :: :ok | {:error, :already_exists}
  def install(repo_module, opts \\ []) when is_atom(repo_module) do
    if repo_module.config()[:log] != false do
      :ok
    else
      :telemetry.attach(
        handler_id(repo_module),
        repo_module.config()[:telemetry_prefix] ++ [:query],
        &__MODULE__.telemetry_handler/4,
        opts
      )
    end
  end

  @doc """
  Detaches a previously attached handler for a given Repo.

  Returns the result from the call to `:telemetry.detach/1`
  """
  @spec uninstall(repo_module :: module()) :: :ok | {:error, :not_found}
  def uninstall(repo_module) when is_atom(repo_module) do
    :telemetry.detach(handler_id(repo_module))
  end

  @doc """
  Gets the handler_id for a given Repo.
  """
  @spec handler_id(repo_module :: module()) :: list()
  def handler_id(repo_module) do
    config = repo_module.config()
    [:ecto_dev_logger] ++ config[:telemetry_prefix]
  end

  @doc "Telemetry handler which logs queries."
  @spec telemetry_handler(
          :telemetry.event_name(),
          :telemetry.event_measurements(),
          :telemetry.event_metadata(),
          [option()]
        ) :: :ok
  def telemetry_handler(_event_name, measurements, metadata, config) do
    ignore_event_callback = config[:ignore_event_callback] || (&ignore_event/1)
    before_inline_callback = config[:before_inline_callback] || (&before_inline/1)

    if !Logbook.enabled?(@logbook_tag, :debug) or ignore_event_callback.(metadata) do
      :ok
    else
      config[:debug_telemetry_metadata] && Logbook.debug(@logbook_tag, inspect(metadata))

      Logbook.debug(@logbook_tag, fn ->
        query = String.Chars.to_string(metadata.query)
        reset_color = (config[:colorize] && IO.ANSI.enabled?() && @reset_color) || ""

        log_query =
          before_inline_callback.(query)
          |> maybe_inline_params(metadata, config, reset_color)
          |> Ecto.DevLogger.Colors.colorize_sql(reset_color)

        log_metadata =
          [query: log_ok_error(metadata.result, reset_color)]
          |> maybe_add_md_repo(metadata[:repo], reset_color, config)
          |> maybe_add_md_source(metadata[:source], reset_color)
          |> maybe_add_md_time(:decode_time, measurements, reset_color)
          |> maybe_add_md_time(:query_time, measurements, reset_color)
          |> maybe_add_md_stacktrace(metadata[:stacktrace], metadata.repo)

        {log_query, log_metadata}
      end)
    end
  end

  @doc """
  Default callback for ignoring events

  By default, ignore events from `Oban` and events related to migration queries.
  To override, set `ignore_event: fn _metadata -> false end` option in `install/2`
  """
  @spec ignore_event(map()) :: boolean()
  def ignore_event(metadata) do
    cond do
      metadata[:options][:oban_conf] != nil -> true
      metadata[:options][:schema_migration] == true -> true
      true -> false
    end
  end

  @doc """
  Default callback before inlining params

  By default, do nothing and return the same query
  To override, set `before_inline_callback: fn query -> query end` option in `install/2`

  You can use this callback to format the query using external utility, like `pgformatter`, etc.
  You can set this to `fn query -> String.replace(query, "\"", "") end` to remove pesky quotes.
  """
  @spec before_inline(String.t()) :: String.t()
  def before_inline(query), do: query

  defp maybe_inline_params(query, metadata, conf, reset_color) do
    case conf[:inline_params] do
      true ->
        param_reset_color = (reset_color != "" && __MODULE__.Colors.sql_color(query)) || ""
        repo = (metadata[:repo] && metadata[:repo].__adapter__()) || nil
        __MODULE__.Inline.inline_params(query, metadata[:cast_params], param_reset_color, repo)

      _ ->
        "#{query} #{inspect(metadata[:cast_params])}"
    end
  end

  defp log_ok_error({what, _res}, color) do
    case what do
      :ok -> __MODULE__.Colors.colorize("OK", IO.ANSI.green(), color)
      :error -> __MODULE__.Colors.colorize("ERROR", IO.ANSI.red(), color)
      _ -> __MODULE__.Colors.colorize("#{what}", IO.ANSI.red(), color)
    end
  end

  @spec maybe_add_md_repo(Keyword.t(), module(), atom(), map()) :: Keyword.t()
  defp maybe_add_md_repo(md, repo, color, config) do
    case {repo, config[:log_repo_name]} do
      {nil, _} -> md
      {repo, true} -> md ++ [repo: __MODULE__.Colors.colorize(repo, IO.ANSI.blue(), color)]
      _ -> md
    end
  end

  @spec maybe_add_md_source(Keyword.t(), String.t() | nil, atom()) :: Keyword.t()
  defp maybe_add_md_source(md, source, color) do
    case source do
      nil -> md
      source -> md ++ [source: __MODULE__.Colors.colorize(source, IO.ANSI.blue(), color)]
    end
  end

  @spec maybe_add_md_time(Keyword.t(), atom(), map(), atom()) :: Keyword.t()
  defp maybe_add_md_time(md, key, measurements, color) do
    case measurements do
      %{^key => time} ->
        us = System.convert_time_unit(time, :native, :microsecond)
        ms = div(us, 100) / 10
        md ++ [{key, __MODULE__.Colors.colorize_duration(ms, color)}]

      %{} ->
        md
    end
  end

  defp maybe_add_md_stacktrace(md, stacktrace, repo) do
    with [_ | _] <- stacktrace,
         {mod, fun, arity, info} <- last_non_ecto(Enum.reverse(stacktrace), repo, nil) do
      md ++ [mfa: {mod, fun, arity}, file: info[:file], line: info[:line]]
    else
      _ -> md
    end
  end

  @repo_modules [Ecto.Repo.Queryable, Ecto.Repo.Schema, Ecto.Repo.Transaction]
  defp last_non_ecto([], _repo, last), do: last
  defp last_non_ecto([{mod, _, _, _} | _], repo, last) when mod == repo, do: last
  defp last_non_ecto([{mod, _, _, _} | _], _repo, last) when mod in @repo_modules, do: last
  defp last_non_ecto([last | stacktrace], repo, _last), do: last_non_ecto(stacktrace, repo, last)
end
