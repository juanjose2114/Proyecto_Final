defmodule Emergencias.Core.MascotasCore do
  @moduledoc """
  Algoritmo recursivo de búsqueda de coincidencias (matching) entre reportes
  de mascotas perdidas y encontradas basado en puntaje de similitud.
  """

  alias Emergencias.Modelos.Mascota
  alias Emergencias.Util

  @puntaje_minimo 60

  @doc """
  [RECURSIVIDAD 3] Recorre los reportes activos de mascotas perdidas y los compara
  recursivamente contra las encontradas, devolviendo coincidencias con puntaje >= 60.
  """
  def buscar_coincidencias(perdidas, encontradas)
      when is_list(perdidas) and is_list(encontradas) do
    emparejar_perdidas(perdidas, encontradas, [])
  end

  defp emparejar_perdidas([], _encontradas, acc), do: ordenar_matches(acc)

  defp emparejar_perdidas([%Mascota{estado: :activa} = perdida | resto], encontradas, acc) do
    matches_de_esta = comparar_con_encontradas(perdida, encontradas, [])
    emparejar_perdidas(resto, encontradas, matches_de_esta ++ acc)
  end

  defp emparejar_perdidas([_no_activa | resto], encontradas, acc) do
    emparejar_perdidas(resto, encontradas, acc)
  end

  defp comparar_con_encontradas(_perdida, [], acc), do: acc

  defp comparar_con_encontradas(perdida, [%Mascota{estado: :activa} = encontrada | resto], acc) do
    puntaje = calcular_puntaje(perdida, encontrada)

    nuevo_acc =
      if puntaje >= @puntaje_minimo do
        match = %{
          perdida_id: perdida.id,
          encontrada_id: encontrada.id,
          especie: perdida.especie,
          zona: perdida.zona,
          puntaje: puntaje
        }

        [match | acc]
      else
        acc
      end

    comparar_con_encontradas(perdida, resto, nuevo_acc)
  end

  defp comparar_con_encontradas(perdida, [_no_activa | resto], acc) do
    comparar_con_encontradas(perdida, resto, acc)
  end

  @doc "Calcula el puntaje de similitud (0 a 100) entre dos reportes."
  def calcular_puntaje(%Mascota{} = p, %Mascota{} = e) do
    if Util.normalizar(p.especie) != Util.normalizar(e.especie) do
      0
    else
      40 +
        puntos_iguales(p.zona, e.zona, 25) +
        puntos_iguales(p.color, e.color, 20) +
        puntos_iguales(to_string(p.tamano), to_string(e.tamano), 15)
    end
  end

  defp puntos_iguales(a, b, puntos) do
    if Util.normalizar(to_string(a)) == Util.normalizar(to_string(b)), do: puntos, else: 0
  end

  defp ordenar_matches([]), do: []
  defp ordenar_matches([h | t]), do: insertar_match(h, ordenar_matches(t))

  defp insertar_match(m, []), do: [m]

  defp insertar_match(m, [h | t]) do
    if m.puntaje >= h.puntaje, do: [m, h | t], else: [h | insertar_match(m, t)]
  end
end

