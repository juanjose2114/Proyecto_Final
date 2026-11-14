defmodule Emergencias.Modelos.Necesidad do
  @moduledoc "Solicitud de ayuda puntual asociada a una zona, persona o albergue."

  @tipos_validos [:agua, :alimentos, :medicamentos, :primeros_auxilios, :refugio, :transporte, :rescate, :otra]
  @prioridades_validas [:critica, :alta, :media, :baja]
  @estados_validos [:pendiente, :asignada, :en_atencion, :atendida, :cancelada]

  defstruct [
    :id,
    :tipo,
    :descripcion,
    :cantidad_requerida,
    :zona,
    :prioridad,
    :responsable,
    cantidad_asignada: 0,
    estado: :pendiente
  ]

  def tipos_validos, do: @tipos_validos
  def prioridades_validas, do: @prioridades_validas
  def estados_validos, do: @estados_validos
end
