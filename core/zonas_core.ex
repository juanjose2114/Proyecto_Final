defmodule Emergencias.Core.ZonasCore do
  @moduledoc """
  Lógica pura y recorrido recursivo sobre la jerarquía:
  Zona -> Sectores -> Puntos de atención.
  """

  alias Emergencias.Modelos.Zona

  @doc """
  [RECURSIVIDAD 1] Calcula el total acumulado de personas afectadas en una zona,
  sumando las afectadas directas de la zona, sus sectores y los puntos de atención.
  """
  def calcular_afectados_zona(%Zona{personas_afectadas: base, sectores: sectores}) do
    base + sumar_sectores(sectores, 0)
  end

  # Caso base: no quedan sectores por recorrer
  defp sumar_sectores([], acc), do: acc

  # Caso recursivo: suma afectados del sector + sus puntos de atención y avanza con la cola
  defp sumar_sectores([sector | resto], acc) do
    afectados_sector = Map.get(sector, :afectados, 0)
    puntos = Map.get(sector, :puntos_atencion, [])
    total_puntos = sumar_puntos(puntos, 0)

    sumar_sectores(resto, acc + afectados_sector + total_puntos)
  end

  defp sumar_puntos([], acc), do: acc

  defp sumar_puntos([punto | resto], acc) do
    sumar_puntos(resto, acc + Map.get(punto, :afectados, 0))
  end

  @doc "Construye un resumen estadístico completo de la zona."
  def estadisticas_zona(%Zona{} = zona) do
    %{
      codigo: zona.codigo,
      nombre: zona.nombre,
      nivel_afectacion: zona.nivel_afectacion,
      total_sectores: length(zona.sectores),
      total_afectados: calcular_afectados_zona(zona)
    }
  end
end
