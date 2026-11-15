defmodule Emergencias.Modelos.MensajeFamiliar do
  @moduledoc "Mensaje dirigido a localizar o comunicarse con una persona o familia."

  defstruct [
    :id,
    :fecha,
    :remitente,
    :destinatario_doc,
    :contenido,
    estado: :pendiente
  ]
end
