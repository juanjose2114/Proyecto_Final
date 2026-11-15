defmodule Emergencias.Core.NecesidadesCore do
  @moduledoc """
  Lógica pura para filtrado, ordenamiento recursivo por prioridad
  y validación de transiciones de estado en necesidades.
  """

  alias Emergencias.Modelos.Necesidad

  @peso_prioridad %{critica: 1, alta: 2, media: 3, baja: 4}

  @doc """
  [RECURSIVIDAD 2] Filtra una lista de necesidades según criterios (Keyword List)
  y las retorna ordenadas de mayor a menor prioridad.
  """
  def filtrar_y_priorizar(necesidades, filtros \\ []) when is_list(necesidades) do
    filtrar_recursivo(necesidades, filtros, [])
  end

  defp filtrar_recursivo([], _filtros, acc), do: acc

  defp filtrar_recursivo([necesidad | resto], filtros, acc) do
    nuevo_acc =
      if cumple_filtros?(necesidad, filtros) do
        insertar_por_prioridad(necesidad, acc)
      else
        acc
      end

    filtrar_recursivo(resto, filtros, nuevo_acc)
  end

  # Inserción recursiva ordenada por peso de prioridad
  defp insertar_por_prioridad(nueva, []), do: [nueva]

  defp insertar_por_prioridad(nueva, [cabeza | cola]) do
    if peso(nueva.prioridad) <= peso(cabeza.prioridad) do
      [nueva, cabeza | cola]
    else
      [cabeza | insertar_por_prioridad(nueva, cola)]
    end
  end

  defp peso(prioridad), do: Map.get(@peso_prioridad, prioridad, 5)

  defp cumple_filtros?(_necesidad, []), do: true

  defp cumple_filtros?(necesidad, [{clave, valor} | resto]) do
    Map.get(necesidad, clave) == valor and cumple_filtros?(necesidad, resto)
  end

  @doc "Valida que una necesidad pueda recibir recursos sin cerrarse dos veces."
  def validar_asignacion(%Necesidad{estado: estado}) when estado in [:atendida, :cancelada] do
    {:error, :necesidad_ya_cerrada}
  end

  def validar_asignacion(%Necesidad{} = necesidad), do: {:ok, necesidad}

  @doc "Actualiza la cantidad asignada y calcula el nuevo estado."
  def aplicar_asignacion(%Necesidad{} = necesidad, cantidad)
      when is_integer(cantidad) and cantidad > 0 do
    with {:ok, _} <- validar_asignacion(necesidad) do
      nueva_asignada = necesidad.cantidad_asignada + cantidad

      nuevo_estado =
        if nueva_asignada >= necesidad.cantidad_requerida do
          :atendida
        else
          :asignada
        end

      {:ok, %{necesidad | cantidad_asignada: nueva_asignada, estado: nuevo_estado}}
    end
  end
end
