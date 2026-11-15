defmodule Emergencias.ConcurrenciaTest do
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

  test "50 litros de agua ante dos solicitudes paralelas de 30L y 25L" do
    {:ok, _} = Emergencias.connect("laura", "1234", :coordinador, "centro")
    {:ok, _} = Emergencias.connect("carlos", "5678", :coordinador, "centro")

    {:ok, n1} = Emergencias.registrar_necesidad("laura", :agua, 30, :critica, "centro", "Sector 1")
    {:ok, n2} = Emergencias.registrar_necesidad("carlos", :agua, 25, :alta, "centro", "Sector 2")
    {:ok, _} = Emergencias.registrar_recurso("laura", "R001", "agua", :agua, 50, "litros", "centro_acopio_1")

    t1 = Task.async(fn -> Emergencias.asignar_recurso("laura", n1.id, "agua", 30) end)
    t2 = Task.async(fn -> Emergencias.asignar_recurso("carlos", n2.id, "agua", 25) end)

    resultados = [Task.await(t1), Task.await(t2)]

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, :inventario_insuficiente}, &1)) == 1
  end

  test "Cupo único en albergue ante dos ingresos simultáneos" do
    {:ok, _} = Emergencias.connect("admin", "admin", :administrador, "norte")
    {:ok, _} = Emergencias.registrar_albergue("admin", "A01", "Albergue Norte", "norte", 1)

    t1 = Task.async(fn -> Emergencias.registrar_ingreso_albergue("admin", "A01", "1001") end)
    t2 = Task.async(fn -> Emergencias.registrar_ingreso_albergue("admin", "A01", "1002") end)

    resultados = [Task.await(t1), Task.await(t2)]

    assert Enum.count(resultados, &match?({:ok, _}, &1)) == 1
    assert Enum.count(resultados, &match?({:error, :capacidad_maxima_alcanzada}, &1)) == 1
  end
end
