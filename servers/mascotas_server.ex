defmodule Emergencias.Servers.MascotasServer do
  @moduledoc """
  GenServer encargado de reportes de mascotas perdidas/encontradas
  y confirmación atómica de coincidencias (matching).
  """
  use GenServer

  alias Emergencias.Modelos.Mascota
  alias Emergencias.Core.MascotasCore
  alias Emergencias.{Persistencia, Util}

  @archivo "mascotas.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def reportar_mascota(tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto) do
    GenServer.call(
      __MODULE__,
      {:reportar, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona, contacto}
    )
  end

  def consultar_mascotas(filtros \\ []) do
    GenServer.call(__MODULE__, {:consultar, filtros})
  end

  def buscar_coincidencias do
    GenServer.call(__MODULE__, :buscar_coincidencias)
  end

  def confirmar_coincidencia(perdida_id, encontrada_id) do
    GenServer.call(__MODULE__, {:confirmar_match, perdida_id, encontrada_id})
  end

  # --- Callbacks del Servidor ---

  @impl true
  def init(_) do
    case Persistencia.cargar(@archivo, %{}) do
      {:ok, estado} -> {:ok, estado}
      _ -> {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:reportar, tipo, especie, nombre, caract, color, tamano, zona, contacto}, _from, state) do
    if tipo not in Mascota.tipos_validos() do
      {:reply, {:error, :tipo_reporte_mascota_invalido}, state}
    else
      numero = map_size(state) + 1
      prefijo = if tipo == :perdida, do: "MP", else: "ME"
      id = prefijo <> String.pad_leading(Integer.to_string(numero), 3, "0")

      mascota = %Mascota{
        id: id,
        tipo_reporte: tipo,
        especie: especie,
        nombre: nombre || "desconocido",
        caracteristicas: caract,
        color: color,
        tamano: tamano,
        zona: zona,
        contacto: contacto,
        estado: :activa
      }

      nuevo_estado = Map.put(state, id, mascota)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, mascota}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:consultar, filtros}, _from, state) do
    lista =
      state
      |> Map.values()
      |> Enum.filter(fn m ->
        Enum.all?(filtros, fn {k, v} ->
          Util.normalizar(to_string(Map.get(m, k))) == Util.normalizar(to_string(v))
        end)
      end)

    {:reply, lista, state}
  end

  @impl true
  def handle_call(:buscar_coincidencias, _from, state) do
    todas = Map.values(state)
    perdidas = Enum.filter(todas, &(&1.tipo_reporte == :perdida))
    encontradas = Enum.filter(todas, &(&1.tipo_reporte == :encontrada))

    matches = MascotasCore.buscar_coincidencias(perdidas, encontradas)
    {:reply, matches, state}
  end

  @impl true
  def handle_call({:confirmar_match, perdida_id, encontrada_id}, _from, state) do
    with {:ok, p} <- fetch_mascota(state, perdida_id),
         {:ok, e} <- fetch_mascota(state, encontrada_id),
         :ok <- validar_pareja(p, e) do
      p_resuelta = %{p | estado: :resuelta, match_id: e.id}
      e_resuelta = %{e | estado: :resuelta, match_id: p.id}

      nuevo_estado =
        state
        |> Map.put(p.id, p_resuelta)
        |> Map.put(e.id, e_resuelta)

      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, %{perdida: p_resuelta, encontrada: e_resuelta}}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  defp fetch_mascota(state, id) do
    case Map.get(state, id) do
      nil -> {:error, :reporte_mascota_no_encontrado}
      m -> {:ok, m}
    end
  end

  defp validar_pareja(%Mascota{estado: :resuelta}, _), do: {:error, :reporte_ya_resuelto}
  defp validar_pareja(_, %Mascota{estado: :resuelta}), do: {:error, :reporte_ya_resuelto}

  defp validar_pareja(%Mascota{tipo_reporte: :perdida}, %Mascota{tipo_reporte: :encontrada}),
    do: :ok

  defp validar_pareja(_, _), do: {:error, :tipos_reporte_incompatibles}
end
