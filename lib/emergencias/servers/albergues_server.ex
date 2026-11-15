defmodule Emergencias.Servers.AlberguesServer do
  @moduledoc """
  GenServer encargado de los albergues, control de cupos y ocupación.
  """
  use GenServer

  alias Emergencias.Modelos.Albergue
  alias Emergencias.Core.AlberguesCore
  alias Emergencias.Persistencia

  @archivo "albergues.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar_albergue(codigo, nombre, zona, capacidad_maxima) do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad_maxima})
  end

  def registrar_ingreso(codigo_albergue, documento) do
    GenServer.call(__MODULE__, {:ingreso, codigo_albergue, documento})
  end

  def registrar_salida(codigo_albergue, documento) do
    GenServer.call(__MODULE__, {:salida, codigo_albergue, documento})
  end

  def consultar_albergue(codigo_albergue) do
    GenServer.call(__MODULE__, {:consultar, codigo_albergue})
  end

  def reporte_ocupacion do
    GenServer.call(__MODULE__, :reporte_ocupacion)
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
  def handle_call({:registrar, codigo, nombre, zona, capacidad_maxima}, _from, state) do
    cond do
      Map.has_key?(state, codigo) ->
        {:reply, {:error, :albergue_ya_existe}, state}

      not is_integer(capacidad_maxima) or capacidad_maxima <= 0 ->
        {:reply, {:error, :capacidad_debe_ser_positiva}, state}

      true ->
        albergue = %Albergue{
          codigo: codigo,
          nombre: nombre,
          zona: zona,
          capacidad_maxima: capacidad_maxima,
          ocupantes: MapSet.new()
        }

        nuevo_estado = Map.put(state, codigo, albergue)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, albergue}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:ingreso, codigo, documento}, _from, state) do
    with {:ok, albergue} <- fetch_albergue(state, codigo),
         {:ok, actualizado} <- AlberguesCore.registrar_ingreso(albergue, documento) do
      nuevo_estado = Map.put(state, codigo, actualizado)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, AlberguesCore.estado_cupos(actualizado)}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:salida, codigo, documento}, _from, state) do
    with {:ok, albergue} <- fetch_albergue(state, codigo),
         {:ok, actualizado} <- AlberguesCore.registrar_salida(albergue, documento) do
      nuevo_estado = Map.put(state, codigo, actualizado)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, AlberguesCore.estado_cupos(actualizado)}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:consultar, codigo}, _from, state) do
    case fetch_albergue(state, codigo) do
      {:ok, albergue} -> {:reply, {:ok, AlberguesCore.estado_cupos(albergue)}, state}
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call(:reporte_ocupacion, _from, state) do
    ranking =
      state
      |> Map.values()
      |> AlberguesCore.reporte_mayor_ocupacion()

    {:reply, ranking, state}
  end

  defp fetch_albergue(state, codigo) do
    case Map.get(state, codigo) do
      nil -> {:error, :albergue_no_encontrado}
      alb -> {:ok, alb}
    end
  end
end
