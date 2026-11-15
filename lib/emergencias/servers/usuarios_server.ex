defmodule Emergencias.Servers.UsuariosServer do
  @moduledoc """
  GenServer encargado de la gestión de usuarios, sesiones, roles y bitácora.
  """
  use GenServer

  alias Emergencias.Modelos.Usuario
  alias Emergencias.{Persistencia, Util}

  @archivo "usuarios.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def connect(username, password, rol \\ :ciudadano, zona \\ "general", nombre_completo \\ nil) do
    GenServer.call(__MODULE__, {:connect, username, password, rol, zona, nombre_completo})
  end

  def disconnect(username) do
    GenServer.call(__MODULE__, {:disconnect, username})
  end

  def registrar_actividad(username, accion) do
    GenServer.call(__MODULE__, {:registrar_actividad, username, accion})
  end

  def obtener_usuario(username) do
    GenServer.call(__MODULE__, {:obtener_usuario, username})
  end

  def listar_usuarios do
    GenServer.call(__MODULE__, :listar_usuarios)
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
  def handle_call({:connect, username, password, rol, zona, nombre_completo}, _from, state) do
    cond do
      String.trim(to_string(username)) == "" or String.trim(to_string(password)) == "" ->
        {:reply, {:error, :credenciales_vacias}, state}

      rol not in Usuario.roles_validos() ->
        {:reply, {:error, :rol_invalido}, state}

      Map.has_key?(state, username) ->
        usuario = Map.get(state, username)

        if usuario.password == password do
          evento = {Util.fecha_actual(), "Inicio de sesión"}
          actualizado = %{usuario | conectado?: true, bitacora: [evento | usuario.bitacora]}
          nuevo_estado = Map.put(state, username, actualizado)
          Persistencia.guardar(@archivo, nuevo_estado)
          {:reply, {:ok, actualizado}, nuevo_estado}
        else
          {:reply, {:error, :contrasena_incorrecta}, state}
        end

      true ->
        # Registro automático si no existe
        evento = {Util.fecha_actual(), "Registro automático y conexión"}

        nuevo_usuario = %Usuario{
          username: username,
          password: password,
          nombre_completo: nombre_completo || username,
          rol: rol,
          zona_principal: zona,
          conectado?: true,
          bitacora: [evento]
        }

        nuevo_estado = Map.put(state, username, nuevo_usuario)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, nuevo_usuario}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:disconnect, username}, _from, state) do
    case Map.get(state, username) do
      nil ->
        {:reply, {:error, :usuario_no_encontrado}, state}

      usuario ->
        evento = {Util.fecha_actual(), "Cierre de sesión"}
        actualizado = %{usuario | conectado?: false, bitacora: [evento | usuario.bitacora]}
        nuevo_estado = Map.put(state, username, actualizado)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, actualizado}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:registrar_actividad, username, accion}, _from, state) do
    case Map.get(state, username) do
      nil ->
        {:reply, {:error, :usuario_no_encontrado}, state}

      usuario ->
        evento = {Util.fecha_actual(), accion}
        actualizado = %{usuario | bitacora: [evento | usuario.bitacora]}
        nuevo_estado = Map.put(state, username, actualizado)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, actualizado}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:obtener_usuario, username}, _from, state) do
    case Map.get(state, username) do
      nil -> {:reply, {:error, :usuario_no_encontrado}, state}
      usuario -> {:reply, {:ok, usuario}, state}
    end
  end

  @impl true
  def handle_call(:listar_usuarios, _from, state) do
    {:reply, Map.values(state), state}
  end
end
