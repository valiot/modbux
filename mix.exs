defmodule Modbux.Mixfile do
  use Mix.Project

  @version "0.3.11"
  @source_url "https://github.com/valiot/modbux"


  def project do
    [
      app: :modbux,
      version: @version,
      elixir: "~> 1.8",
      name: "Modbux",
      docs: docs(),
      description: description(),
      package: package(),
      source_url: @source_url,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
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

  defp extras(), do: ["README.md"]

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/modbux",
      logo: "assets/images/valiot-logo-blue.png",
      source_url: @source_url,
      extras: extras(),
      groups_for_modules: [
        "Modbus RTU": [
          Modbux.Rtu.Master,
          Modbux.Rtu.Slave,
        ],
        "Modbus TCP": [
          Modbux.Tcp.Client,
          Modbux.Tcp.Server,
        ],
      ]
    ]
  end

  defp description do
    "Modbus for network and serial communication, this library implements TCP (Client & Server) and RTU (Master & Slave) protocols."
  end

  defp aliases do
    [docs: ["docs", &copy_images/1]]
  end

  defp copy_images(_) do
    File.ls!("assets/images")
    |> Enum.each(fn x ->
      File.cp!("assets/images/#{x}", "doc/assets/#{x}")
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
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/valiot/modbux"}
    ]
  end
end
