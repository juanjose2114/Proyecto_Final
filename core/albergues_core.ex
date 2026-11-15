defmodule Emergencias.Core.AlberguesCore do
  @moduledoc """
  Reglas puras de control de aforo con MapSet y generación recursiva
  del reporte de albergues con mayor nivel de ocupación.
  """

  alias Emergencias.Modelos.Albergue

  @doc "Registra el ingreso de una persona validando cupos disponibles y no duplicidad."
  def registrar_ingreso(%Albergue{capacidad_maxima: max, ocupantes: ocupantes} = alb, documento)
      when is_binary(documento) do
    cond do
      MapSet.member?(ocupantes, documento) ->
        {:error, :persona_ya_registrada_en_albergue}

      MapSet.size(ocupantes) >= max ->
        {:error, :capacidad_maxima_alcanzada}

      true ->
        {:ok, %{alb | ocupantes: MapSet.put(ocupantes, documento)}}
    end
  end

  @doc "Registra la salida de una persona del albergue."
  def registrar_salida(%Albergue{ocupantes: ocupantes} = alb, documento)
      when is_binary(documento) do
    if MapSet.member?(ocupantes, documento) do
      {:ok, %{alb | ocupantes: MapSet.delete(ocupantes, documento)}}
    else
      {:error, :persona_no_encontrada_en_albergue}
    end
  end

  @doc "Consulta la ocupación actual y los cupos libres de un albergue."
  def estado_cupos(%Albergue{capacidad_maxima: max, ocupantes: ocupantes} = alb) do
    actual = MapSet.size(ocupantes)
    porcentaje = if max > 0, do: Float.round(actual * 100 / max, 1), else: 0.0

    %{
      codigo: alb.codigo,
      nombre: alb.nombre,
      zona: alb.zona,
      capacidad_maxima: max,
      ocupacion_actual: actual,
      cupos_disponibles: max - actual,
      porcentaje_ocupacion: porcentaje
    }
  end

  @doc """
  [RECURSIVIDAD 4] Recorre los albergues, calcula su nivel de ocupación
  y construye recursivamente el reporte ordenado de mayor a menor ocupación.
  """
  def reporte_mayor_ocupacion(albergues) when is_list(albergues) do
    construir_ranking(albergues, [])
  end

  defp construir_ranking([], acc), do: acc

  defp construir_ranking([albergue | resto], acc) do
    info = estado_cupos(albergue)
    construir_ranking(resto, insertar_por_ocupacion(info, acc))
  end

  defp insertar_por_ocupacion(nuevo, []), do: [nuevo]

  defp insertar_por_ocupacion(nuevo, [cabeza | cola]) do
    if nuevo.porcentaje_ocupacion >= cabeza.porcentaje_ocupacion do
      [nuevo, cabeza | cola]
    else
      [cabeza | insertar_por_ocupacion(nuevo, cola)]
    end
  end
end
