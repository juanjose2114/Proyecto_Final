defmodule Emergencias.Modelos.Zona do
  @moduledoc """
  Estructura jerárquica de zona afectada: Zona -> Sectores -> Puntos de atención.
  Se utiliza en el recorrido recursivo de estadísticas acumuladas.
  """

  @niveles_validos [:critico, :alto, :medio, :bajo]

  defstruct [
    :codigo,
    :nombre,
    :nivel_afectacion,
    personas_afectadas: 0,
    sectores: []
    # Cada sector tiene la forma:
    # %{codigo: String.t(), nombre: String.t(), afectados: integer(), puntos_atencion: [%{nombre: String.t(), afectados: integer()}]}
  ]

  def niveles_validos, do: @niveles_validos
end
