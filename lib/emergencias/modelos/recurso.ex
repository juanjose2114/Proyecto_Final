defmodule Emergencias.Modelos.Recurso do
  @moduledoc "Recurso disponible en centros de acopio, albergues o puntos de atención."

  defstruct [
    :codigo,
    :nombre,
    :categoria,
    :cantidad,
    :unidad,
    :ubicacion,
    historial: []
  ]
end
