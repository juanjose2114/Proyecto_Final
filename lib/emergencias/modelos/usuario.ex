defmodule Emergencias.Modelos.Usuario do
  @moduledoc "Estructura que representa un usuario del sistema, su rol y bitácora."

  @roles_validos [:ciudadano, :voluntario, :coordinador, :administrador]

  defstruct [
    :username,
    :password,
    :nombre_completo,
    :rol,
    :zona_principal,
    conectado?: false,
    bitacora: []
  ]

  def roles_validos, do: @roles_validos
end
