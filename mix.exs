defmodule Modbux.Mixfile do
  use Mix.Project

  def project do
    [
      app: :modbux,
      version: "0.3.10",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      name: "Modbux",
      package: package(),
      source_url: "https://github.com/valiot/modbux",
      aliases: aliases(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:circuits_uart, "~> 1.3"},
      {:ex_doc, "~> 0.19", only: :dev},
      {:ring_logger, "~> 0.4"}
    ]
  end

  defp description do
    "Modbus for network and serial communication, this library implements TCP (Client & Server) and RTU (Master & Slave) protocols."
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.mkdir("doc/assets/")

    File.ls!("assets")
    |> Enum.each(fn x ->
      File.cp!("assets/#{x}", "doc/assets/#{x}")
    end)
  end

  defp package do
    [
      files: [
        "lib",
        "test",
        "mix.exs",
        "README.md",
        "LICENSE"
      ],
      maintainers: ["valiot"],
      licenses: ["Apache"],
      links: %{"GitHub" => "https://github.com/valiot/modbux"}
    ]
  end
end
