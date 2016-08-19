defmodule Modbus.Mixfile do
  use Mix.Project

  def project do
    [app: :modbus,
     version: "0.1.0",
     elixir: "~> 1.3",
     compilers: [:elixir, :app],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    []
  end

  defp deps do
    [
      {:ex_doc, "~> 0.12", only: :dev},
    ]
  end

  defp description do
    """
    Modbus for Elixir.
    """
  end

  defp package do
    [
     name: :modbus,
     files: ["lib", "test", "mix.*", "*.exs", "*.md", ".gitignore"],
     maintainers: ["Samuel Ventura"],
     licenses: ["Apache 2.0"],
     links: %{"GitHub" => "https://github.com/samuelventura/modbus/",
              "Docs" => "http://samuelventura.github.io/modbus/"}]
  end

  defp aliases do
    [
      "opto22": ["run opto22.exs"],
    ]
  end
end
