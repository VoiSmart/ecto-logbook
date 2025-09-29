defmodule EctoLogbook.MixProject do
  use Mix.Project
  @version "1.14.4"
  @source_url "https://github.com/VoiSmart/ecto-logbook"

  def project do
    [
      app: :ecto_logbook,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: "An alternative logger for Ecto queries using Logbook",
      package: package(),
      deps: deps(),
      docs: [
        formatters: ["html"],
        main: "readme",
        extras: ["README.md": [title: "README"]],
        source_url: @source_url,
        source_ref: "v#{@version}"
      ]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{GitHub: @source_url}
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},
      {:jason, "~> 1.4"},
      {:logbook, "~> 4.0"},
      {:geo, "~> 3.5 or ~> 4.0", optional: true},
      {:ecto_sql, "~> 3.12", only: :test},
      {:postgrex, "~> 0.20", only: :test},
      {:ecto_sqlite3, "~> 0.19", only: :test},
      {:excoveralls, "~> 0.18", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
