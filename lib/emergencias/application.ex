defmodule Emergencias.Application do
  @moduledoc """
  Supervisor raíz OTP encargado de iniciar y monitorear los procesos
  GenServer del sistema de emergencias bajo estrategia :one_for_one.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Emergencias.Servers.UsuariosServer,
      Emergencias.Servers.ZonasServer,
      Emergencias.Servers.NecesidadesServer,
      Emergencias.Servers.RecursosServer,
      Emergencias.Servers.PersonasServer,
      Emergencias.Servers.MascotasServer,
      Emergencias.Servers.AlberguesServer
    ]

    opts = [strategy: :one_for_one, name: Emergencias.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
