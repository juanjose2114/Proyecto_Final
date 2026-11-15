defmodule Emergencias.Servers.NecesidadesServer do
  @moduledoc """
  GenServer encargado de las necesidades puntuales, priorización y control de estados.
  """
  use GenServer

  alias Emergencias.Modelos.Necesidad
  alias Emergencias.Core.NecesidadesCore
  alias Emergencias.Persistencia

  @archivo "necesidades.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar_necesidad(tipo, cantidad, prioridad, zona, descripcion, responsable \\ "sistema") do
    GenServer.call(__MODULE__, {:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable})
  end

  def listar_necesidades(filtros \\ []) do
    GenServer.call(__MODULE__, {:listar, filtros})
  end

  def obtener_necesidad(id) do
    GenServer.call(__MODULE__, {:obtener, id})
  end

  def aplicar_asignacion(id, cantidad) do
    GenServer.call(__MODULE__, {:aplicar_asignacion, id, cantidad})
  end

  def cambiar_estado(id, nuevo_estado) do
    GenServer.call(__MODULE__, {:cambiar_estado, id, nuevo_estado})
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
  def handle_call({:registrar, tipo, cantidad, prioridad, zona, descripcion, responsable}, _from, state) do
    cond do
      tipo not in Necesidad.tipos_validos() ->
        {:reply, {:error, :tipo_necesidad_invalido}, state}

      prioridad not in Necesidad.prioridades_validas() ->
        {:reply, {:error, :prioridad_invalida}, state}

      not is_integer(cantidad) or cantidad <= 0 ->
        {:reply, {:error, :cantidad_debe_ser_positiva}, state}

      true ->
        numero = map_size(state) + 1
        id = "N" <> String.pad_leading(Integer.to_string(numero), 3, "0")

        necesidad = %Necesidad{
          id: id,
          tipo: tipo,
          descripcion: descripcion,
          cantidad_requerida: cantidad,
          zona: zona,
          prioridad: prioridad,
          responsable: responsable,
          cantidad_asignada: 0,
          estado: :pendiente
        }

        nuevo_estado = Map.put(state, id, necesidad)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, necesidad}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:listar, filtros}, _from, state) do
    ordenadas =
      state
      |> Map.values()
      |> NecesidadesCore.filtrar_y_priorizar(filtros)

    {:reply, ordenadas, state}
  end

  @impl true
  def handle_call({:obtener, id}, _from, state) do
    case Map.get(state, id) do
      nil -> {:reply, {:error, :necesidad_no_encontrada}, state}
      nec -> {:reply, {:ok, nec}, state}
    end
  end

  @impl true
  def handle_call({:aplicar_asignacion, id, cantidad}, _from, state) do
    with {:ok, nec} <- fetch_necesidad(state, id),
         {:ok, actualizada} <- NecesidadesCore.aplicar_asignacion(nec, cantidad) do
      nuevo_estado = Map.put(state, id, actualizada)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, actualizada}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:cambiar_estado, id, nuevo_est}, _from, state) do
    with {:ok, nec} <- fetch_necesidad(state, id),
         :ok <- validar_transicion(nec.estado, nuevo_est) do
      actualizada = %{nec | estado: nuevo_est}
      nuevo_estado = Map.put(state, id, actualizada)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, actualizada}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  defp fetch_necesidad(state, id) do
    case Map.get(state, id) do
      nil -> {:error, :necesidad_no_encontrada}
      nec -> {:ok, nec}
    end
  end

  defp validar_transicion(actual, _nuevo) when actual in [:atendida, :cancelada] do
    {:error, :necesidad_ya_cerrada}
  end

  defp validar_transicion(_actual, nuevo) do
    if nuevo in Necesidad.estados_validos(), do: :ok, else: {:error, :estado_invalido}
  end
end
