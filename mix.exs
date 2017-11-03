defmodule Paytm.Mixfile do
  use Mix.Project

  def project do
    [
      app: :paytm,
      version: "0.4.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      description: "Paytm API client for Elixir with Wallet and OAuth API support"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["Nihal Gonsalves <nihal@wunder.org>", "Robert Salama <robert@wunder.org>", "Bruno Santos <bruno.santos@wunder.org>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/wundercar/paytm"}
    ]
  end

  defp deps do
    [
      {:httpoison, "~> 0.13"},
      {:poison, "~> 3.1"},
      {:money, "~> 1.2.1"},
      {:exvcr, "~> 0.8", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev},
      {:uuid, "~> 1.1", only: [:dev, :test]}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]
end
