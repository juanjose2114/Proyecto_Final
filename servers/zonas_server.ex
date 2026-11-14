defmodule Emergencias.Servers.ZonasServer do
  @moduledoc """
  GenServer encargado de las zonas afectadas, sus sectores y puntos de atención.
  """
  use GenServer

  alias Emergencias.Modelos.Zona
  alias Emergencias.Core.ZonasCore
  alias Emergencias.Persistencia

  @archivo "zonas.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar_zona(codigo, nombre, nivel_afectacion, personas_afectadas \\ 0) do
    GenServer.call(__MODULE__, {:registrar_zona, codigo, nombre, nivel_afectacion, personas_afectadas})
  end

  def agregar_sector(codigo_zona, sector) do
    GenServer.call(__MODULE__, {:agregar_sector, codigo_zona, sector})
  end

  def consultar_zona(codigo) do
    GenServer.call(__MODULE__, {:consultar_zona, codigo})
  end

  def listar_zonas do
    GenServer.call(__MODULE__, :listar_zonas)
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
  def handle_call({:registrar_zona, codigo, nombre, nivel, afectados}, _from, state) do
    cond do
      Map.has_key?(state, codigo) ->
        {:reply, {:error, :zona_ya_existe}, state}

      nivel not in Zona.niveles_validos() ->
        {:reply, {:error, :nivel_afectacion_invalido}, state}

      not is_integer(afectados) or afectados < 0 ->
        {:reply, {:error, :cantidad_no_puede_ser_negativa}, state}

      true ->
        zona = %Zona{
          codigo: codigo,
          nombre: nombre,
          nivel_afectacion: nivel,
          personas_afectadas: afectados,
          sectores: []
        }

        nuevo_estado = Map.put(state, codigo, zona)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, zona}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:agregar_sector, codigo_zona, sector}, _from, state) do
    case Map.get(state, codigo_zona) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, state}

      zona ->
        actualizada = %{zona | sectores: [sector | zona.sectores]}
        nuevo_estado = Map.put(state, codigo_zona, actualizada)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, actualizada}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:consultar_zona, codigo}, _from, state) do
    case Map.get(state, codigo) do
      nil ->
        {:reply, {:error, :zona_no_encontrada}, state}

      zona ->
        stats = ZonasCore.estadisticas_zona(zona)
        {:reply, {:ok, %{zona: zona, estadisticas: stats}}, state}
    end
  end

  @impl true
  def handle_call(:listar_zonas, _from, state) do
    resumenes =
      state
      |> Map.values()
      |> Enum.map(&ZonasCore.estadisticas_zona/1)

    {:reply, resumenes, state}
  end
end
