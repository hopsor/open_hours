defmodule OpenHours.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :open_hours,
      version: @version,
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :tzdata]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:tzdata, "~> 1.1"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp package() do
    [
      files: ["lib", "mix.exs", "README.md", "LICENSE.md"],
      maintainers: ["Victor Viruete"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/hopsor/open_hours"
      }
    ]
  end

  defp description() do
    """
    Time calculations using business hours
    """
  end

  defp docs() do
    [
      main: "OpenHours",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/open_hours",
      source_url: "https://github.com/hopsor/open_hours"
    ]
  end
end
