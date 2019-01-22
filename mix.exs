defmodule OpenHours.MixProject do
  use Mix.Project

  def project do
    [
      app: :open_hours,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:tzdata, git: "https://github.com/lau/tzdata.git", tag: "master"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end
end
