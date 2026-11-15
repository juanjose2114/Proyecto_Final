defmodule Emergencias.Servers.PersonasServer do
  @moduledoc """
  GenServer encargado de localizar personas afectadas, conservar su historial
  de estados y gestionar la mensajería entre familiares.
  """
  use GenServer

  alias Emergencias.Modelos.{Persona, MensajeFamiliar}
  alias Emergencias.{Persistencia, Util}

  @archivo_personas "personas.txt"
  @archivo_mensajes "mensajes.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def reportar_persona(documento, nombre, zona, estado \\ :reportada, edad \\ 0) do
    GenServer.call(__MODULE__, {:reportar, documento, nombre, zona, estado, edad})
  end

  def actualizar_estado(documento, nuevo_estado) do
    GenServer.call(__MODULE__, {:actualizar_estado, documento, nuevo_estado})
  end

  def buscar_personas(criterio) do
    GenServer.call(__MODULE__, {:buscar, criterio})
  end

  def enviar_mensaje(remitente, destinatario_doc, contenido) do
    GenServer.call(__MODULE__, {:enviar_mensaje, remitente, destinatario_doc, contenido})
  end

  def listar_mensajes(destinatario_doc) do
    GenServer.call(__MODULE__, {:listar_mensajes, destinatario_doc})
  end

  def marcar_mensaje(id_mensaje, nuevo_estado) when nuevo_estado in [:pendiente, :entregado] do
    GenServer.call(__MODULE__, {:marcar_mensaje, id_mensaje, nuevo_estado})
  end

  def resumen_personas do
    GenServer.call(__MODULE__, :resumen)
  end

  # --- Callbacks del Servidor ---

  @impl true
  def init(_) do
    personas =
      case Persistencia.cargar(@archivo_personas, %{}) do
        {:ok, data} -> data
        _ -> %{}
      end

    mensajes =
      case Persistencia.cargar(@archivo_mensajes, []) do
        {:ok, data} -> data
        _ -> []
      end

    {:ok, %{personas: personas, mensajes: mensajes}}
  end

  @impl true
  def handle_call({:reportar, documento, nombre, zona, estado, edad}, _from, state) do
    cond do
      estado not in Persona.estados_validos() ->
        {:reply, {:error, :estado_persona_invalido}, state}

      not is_integer(edad) or edad < 0 ->
        {:reply, {:error, :edad_invalida}, state}

      Map.has_key?(state.personas, documento) ->
        # Si ya existe, actualiza su estado y agrega entrada al historial
        persona = Map.get(state.personas, documento)
        evento = {Util.fecha_actual(), estado}

        actualizada = %{
          persona
          | zona: zona,
            estado: estado,
            historial_estados: [evento | persona.historial_estados]
        }

        nuevas_personas = Map.put(state.personas, documento, actualizada)
        Persistencia.guardar(@archivo_personas, nuevas_personas)
        {:reply, {:ok, actualizada}, %{state | personas: nuevas_personas}}

      true ->
        evento = {Util.fecha_actual(), estado}

        persona = %Persona{
          id: Util.generar_id("P"),
          documento: documento,
          nombre: nombre,
          edad: edad,
          zona: zona,
          estado: estado,
          historial_estados: [evento]
        }

        nuevas_personas = Map.put(state.personas, documento, persona)
        Persistencia.guardar(@archivo_personas, nuevas_personas)
        {:reply, {:ok, persona}, %{state | personas: nuevas_personas}}
    end
  end

  @impl true
  def handle_call({:actualizar_estado, documento, nuevo_estado}, _from, state) do
    cond do
      nuevo_estado not in Persona.estados_validos() ->
        {:reply, {:error, :estado_persona_invalido}, state}

      not Map.has_key?(state.personas, documento) ->
        {:reply, {:error, :persona_no_encontrada}, state}

      true ->
        persona = Map.get(state.personas, documento)
        evento = {Util.fecha_actual(), nuevo_estado}

        actualizada = %{
          persona
          | estado: nuevo_estado,
            historial_estados: [evento | persona.historial_estados]
        }

        nuevas_personas = Map.put(state.personas, documento, actualizada)
        Persistencia.guardar(@archivo_personas, nuevas_personas)
        {:reply, {:ok, actualizada}, %{state | personas: nuevas_personas}}
    end
  end

  @impl true
  def handle_call({:buscar, criterio}, _from, state) do
    resultados =
      state.personas
      |> Map.values()
      |> Enum.filter(fn p ->
        coincide_persona?(p, criterio)
      end)

    {:reply, resultados, state}
  end

  @impl true
  def handle_call({:enviar_mensaje, remitente, destinatario_doc, contenido}, _from, state) do
    if String.trim(to_string(contenido)) == "" do
      {:reply, {:error, :mensaje_vacio}, state}
    else
      mensaje = %MensajeFamiliar{
        id: Util.generar_id("M"),
        fecha: Util.fecha_actual(),
        remitente: remitente,
        destinatario_doc: destinatario_doc,
        contenido: contenido,
        estado: :pendiente
      }

      nuevos_mensajes = [mensaje | state.mensajes]
      Persistencia.guardar(@archivo_mensajes, nuevos_mensajes)
      {:reply, {:ok, mensaje}, %{state | mensajes: nuevos_mensajes}}
    end
  end

  @impl true
  def handle_call({:listar_mensajes, destinatario_doc}, _from, state) do
    encontrados =
      state.mensajes
      |> Enum.filter(fn m -> m.destinatario_doc == destinatario_doc end)
      |> Enum.reverse()

    {:reply, encontrados, state}
  end

  @impl true
  def handle_call({:marcar_mensaje, id_mensaje, nuevo_estado}, _from, state) do
    case Enum.find(state.mensajes, fn m -> m.id == id_mensaje end) do
      nil ->
        {:reply, {:error, :mensaje_no_encontrado}, state}

      _msg ->
        nuevos_mensajes =
          Enum.map(state.mensajes, fn m ->
            if m.id == id_mensaje, do: %{m | estado: nuevo_estado}, else: m
          end)

        Persistencia.guardar(@archivo_mensajes, nuevos_mensajes)
        actualizado = Enum.find(nuevos_mensajes, fn m -> m.id == id_mensaje end)
        {:reply, {:ok, actualizado}, %{state | mensajes: nuevos_mensajes}}
    end
  end

  @impl true
  def handle_call(:resumen, _from, state) do
    {:reply, %{personas: Map.values(state.personas), mensajes: state.mensajes}, state}
  end

  defp coincide_persona?(p, criterio) when is_binary(criterio) do
    q = Util.normalizar(criterio)

    Util.normalizar(p.documento) == q or
      String.contains?(Util.normalizar(p.nombre), q) or
      Util.normalizar(p.zona) == q or
      Util.normalizar(to_string(p.estado)) == q
  end

  defp coincide_persona?(p, filtros) when is_list(filtros) do
    Enum.all?(filtros, fn {k, v} -> Map.get(p, k) == v end)
  end
end
