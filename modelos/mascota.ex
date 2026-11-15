defmodule Emergencias.Modelos.Mascota do
  @moduledoc "Reporte de mascota perdida o encontrada durante la emergencia."

  @tipos_validos [:perdida, :encontrada]
  @estados_validos [:activa, :posible_coincidencia, :resuelta]

  defstruct [
    :id,
    :tipo_reporte,
    :especie,
    :caracteristicas,
    :color,
    :tamano,
    :zona,
    :contacto,
    nombre: "desconocido",
    estado: :activa,
    match_id: nil
  ]

  def tipos_validos, do: @tipos_validos
  def estados_validos, do: @estados_validos
end
