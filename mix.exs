defmodule Modbus.Mixfile do
  use Mix.Project

  def project do
    [
      app: :modbus,
      version: "0.3.7",
      elixir: "~> 1.3",
      compilers: [:elixir, :app],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev},
      {:ring_logger, "~> 0.4"}
    ]
  end

  defp description do
    "Modbus library with TCP Master & Slave implementation."
  end

  defp package do
    [
      name: :modbus,
      files: ["lib", "test", "script", "mix.*", "*.exs", "*.md", ".gitignore", "LICENSE"],
      maintainers: ["Samuel Ventura"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/samuelventura/modbus/"}
    ]
  end
end
