defmodule Xipper.MixProject do
  use Mix.Project

  def project do
    [
      app: :xipper,
      version: "0.1.0",
      description: "Huet's zipper implemented in Elixir",
      package: [
        licenses: ["MIT"],
        maintainers: ["Michael Berkowitz"],
        links: %{
          github: "https://github.com/mikowitz/xipper"
        }
      ],
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.19", only: [:dev, :test]},
      {:mix_test_watch, "~> 0.2", only: [:test], runtime: false},
      {:stream_data, "~> 0.1", only: [:dev, :test]}
    ]
  end
end
