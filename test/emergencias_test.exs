defmodule EmergenciasTest do
  use ExUnit.Case

  setup do
    File.rm_rf!("data")

    for mod <- [
          Emergencias.Servers.UsuariosServer,
          Emergencias.Servers.ZonasServer,
          Emergencias.Servers.NecesidadesServer,
          Emergencias.Servers.RecursosServer,
          Emergencias.Servers.PersonasServer,
          Emergencias.Servers.MascotasServer,
          Emergencias.Servers.AlberguesServer
        ] do
      :sys.replace_state(mod, fn _ ->
        if mod == Emergencias.Servers.PersonasServer,
          do: %{personas: %{}, mensajes: []},
          else: %{}
      end)
    end

    :ok
  end

  test "Flujo completo de coordinación, roles, resumen global y recuperación del Supervisor" do
    {:ok, _} = Emergencias.connect("laura", "1234", :coordinador, "centro")
    {:ok, _} = Emergencias.connect("juan", "0000", :ciudadano, "centro")

    # Control de roles: ciudadano no puede registrar recursos
    assert {:error, :permiso_denegado_para_rol} =
             Emergencias.registrar_recurso("juan", "R001", "agua", :agua, 50, "litros", "bodega")

    {:ok, _} = Emergencias.registrar_recurso("laura", "R001", "agua", :agua, 50, "litros", "bodega")
    {:ok, _} = Emergencias.reportar_persona("juan", "1094888", "Andres", "centro", :localizada, 25)
    {:ok, _} = Emergencias.enviar_mensaje_familiar("juan", "1094888", "Estoy bien en el albergue")

    # Tolerancia a fallos OTP: matar RecursosServer y verificar que el Supervisor lo reinicia con los datos de data/recursos.txt
    pid_viejo = Process.whereis(Emergencias.Servers.RecursosServer)
    Process.exit(pid_viejo, :kill)
    Process.sleep(60)

    pid_nuevo = Process.whereis(Emergencias.Servers.RecursosServer)
    assert pid_nuevo != nil and pid_nuevo != pid_viejo

    {:ok, [recurso]} = Emergencias.listar_recursos("laura")
    assert recurso.cantidad == 50

    {:ok, resumen} = Emergencias.resumen_global("laura")
    assert resumen.personas_localizadas == 1
    assert resumen.total_mensajes == 1
  end
end
