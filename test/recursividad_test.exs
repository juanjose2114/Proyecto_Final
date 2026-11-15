defmodule Emergencias.RecursividadTest do
  use ExUnit.Case

  alias Emergencias.Modelos.{Zona, Necesidad, Mascota, Albergue}
  alias Emergencias.Core.{ZonasCore, NecesidadesCore, MascotasCore, AlberguesCore}

  test "Recursividad 1: suma jerárquica zona -> sectores -> puntos de atención" do
    zona = %Zona{
      codigo: "Z01",
      nombre: "Centro",
      nivel_afectacion: :critico,
      personas_afectadas: 100,
      sectores: [
        %{
          codigo: "S01",
          nombre: "Sector 1",
          afectados: 40,
          puntos_atencion: [
            %{nombre: "Punto A", afectados: 35},
            %{nombre: "Punto B", afectados: 25}
          ]
        }
      ]
    }

    assert ZonasCore.calcular_afectados_zona(zona) == 200
  end

  test "Recursividad 2: filtrado y ordenamiento por prioridad" do
    lista = [
      %Necesidad{id: "N1", tipo: :alimentos, prioridad: :baja, zona: "centro", estado: :pendiente},
      %Necesidad{id: "N2", tipo: :rescate, prioridad: :critica, zona: "centro", estado: :pendiente},
      %Necesidad{id: "N3", tipo: :agua, prioridad: :alta, zona: "norte", estado: :pendiente}
    ]

    ordenadas = NecesidadesCore.filtrar_y_priorizar(lista)
    assert Enum.map(ordenadas, & &1.prioridad) == [:critica, :alta, :baja]

    solo_centro = NecesidadesCore.filtrar_y_priorizar(lista, zona: "centro")
    assert Enum.map(solo_centro, & &1.id) == ["N2", "N1"]
  end

  test "Recursividad 3: algoritmo de matching y puntaje de mascotas" do
    perdidas = [
      %Mascota{id: "MP001", tipo_reporte: :perdida, especie: "perro", color: "negra", tamano: :mediana, zona: "norte", estado: :activa}
    ]

    encontradas = [
      %Mascota{id: "ME001", tipo_reporte: :encontrada, especie: "perro", color: "negra", tamano: :mediana, zona: "norte", estado: :activa},
      %Mascota{id: "ME002", tipo_reporte: :encontrada, especie: "gato", color: "blanca", tamano: :pequena, zona: "sur", estado: :activa}
    ]

    [match] = MascotasCore.buscar_coincidencias(perdidas, encontradas)
    assert match.perdida_id == "MP001"
    assert match.encontrada_id == "ME001"
    assert match.puntaje == 100
  end

  test "Recursividad 4: reporte ordenado de albergues con mayor ocupación" do
    a1 = %Albergue{codigo: "A01", nombre: "Norte", zona: "norte", capacidad_maxima: 10, ocupantes: MapSet.new(["1"])}
    a2 = %Albergue{codigo: "A02", nombre: "Sur", zona: "sur", capacidad_maxima: 4, ocupantes: MapSet.new(["2", "3", "4"])}

    [primero, segundo] = AlberguesCore.reporte_mayor_ocupacion([a1, a2])
    assert primero.codigo == "A02"
    assert primero.porcentaje_ocupacion == 75.0
    assert segundo.codigo == "A01"
  end
end
