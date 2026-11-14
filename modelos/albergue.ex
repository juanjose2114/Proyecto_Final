defmodule Emergencias.Modelos.Albergue do
  @moduledoc """
  Centro de alojamiento temporal. Usa MapSet en `ocupantes` para evitar
  ingresos duplicados y calcular cupos disponibles en O(1).
  """

  defstruct [
    :codigo,
    :nombre,
    :zona,
    :capacidad_maxima,
    ocupantes: MapSet.new()
  ]
end
