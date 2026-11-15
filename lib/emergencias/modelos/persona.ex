defmodule Emergencias.Modelos.Persona do
  @moduledoc "Registro de una persona afectada y su historial de cambios de estado."

  @estados_validos [:sin_informacion, :reportada, :localizada, :trasladada, :en_albergue, :reunificada]

  defstruct [
    :id,
    :documento,
    :nombre,
    :edad,
    :zona,
    estado: :reportada,
    historial_estados: []
  ]

  def estados_validos, do: @estados_validos
end
