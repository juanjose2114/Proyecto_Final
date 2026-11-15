defmodule Emergencias.Servers.RecursosServer do
  @moduledoc """
  GenServer encargado del inventario de recursos y centros de apoyo.
  Garantiza exclusión mutua ante solicitudes concurrentes sobre el mismo recurso.
  """
  use GenServer

  alias Emergencias.Modelos.Recurso
  alias Emergencias.Servers.NecesidadesServer
  alias Emergencias.{Persistencia, Util}

  @archivo "recursos.txt"

  # --- API Cliente ---

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def registrar_recurso(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    GenServer.call(__MODULE__, {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion})
  end

  def entrada_inventario(codigo, cantidad, detalle \\ "Entrada de inventario") do
    GenServer.call(__MODULE__, {:entrada, codigo, cantidad, detalle})
  end

  def salida_inventario(codigo, cantidad, detalle \\ "Salida de inventario") do
    GenServer.call(__MODULE__, {:salida, codigo, cantidad, detalle})
  end

  def asignar_recurso(necesidad_id, recurso_o_tipo, cantidad) do
    GenServer.call(__MODULE__, {:asignar, necesidad_id, recurso_o_tipo, cantidad})
  end

  def transferir_recurso(codigo, origen, destino, cantidad) do
    GenServer.call(__MODULE__, {:transferir, codigo, origen, destino, cantidad})
  end

  def listar_recursos(filtros \\ []) do
    GenServer.call(__MODULE__, {:listar, filtros})
  end

  def recursos_criticos(umbral \\ 25) do
    GenServer.call(__MODULE__, {:criticos, umbral})
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
  def handle_call({:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion}, _from, state) do
    cond do
      Map.has_key?(state, codigo) ->
        {:reply, {:error, :recurso_ya_existe}, state}

      not is_integer(cantidad) or cantidad < 0 ->
        {:reply, {:error, :cantidad_no_puede_ser_negativa}, state}

      true ->
        movimiento = %{
          fecha: Util.fecha_actual(),
          tipo: :entrada,
          cantidad: cantidad,
          detalle: "Registro inicial en #{ubicacion}"
        }

        recurso = %Recurso{
          codigo: codigo,
          nombre: nombre,
          categoria: categoria,
          cantidad: cantidad,
          unidad: unidad,
          ubicacion: ubicacion,
          historial: [movimiento]
        }

        nuevo_estado = Map.put(state, codigo, recurso)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, recurso}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:entrada, codigo, cantidad, detalle}, _from, state)
      when is_integer(cantidad) and cantidad > 0 do
    case Map.get(state, codigo) do
      nil ->
        {:reply, {:error, :recurso_no_encontrado}, state}

      recurso ->
        mov = %{fecha: Util.fecha_actual(), tipo: :entrada, cantidad: cantidad, detalle: detalle}
        actualizado = %{recurso | cantidad: recurso.cantidad + cantidad, historial: [mov | recurso.historial]}
        nuevo_estado = Map.put(state, codigo, actualizado)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, actualizado}, nuevo_estado}
    end
  end

  def handle_call({:entrada, _codigo, _cantidad, _detalle}, _from, state) do
    {:reply, {:error, :cantidad_debe_ser_positiva}, state}
  end

  @impl true
  def handle_call({:salida, codigo, cantidad, detalle}, _from, state)
      when is_integer(cantidad) and cantidad > 0 do
    case Map.get(state, codigo) do
      nil ->
        {:reply, {:error, :recurso_no_encontrado}, state}

      %Recurso{cantidad: disp} when disp < cantidad ->
        {:reply, {:error, :inventario_insuficiente}, state}

      recurso ->
        mov = %{fecha: Util.fecha_actual(), tipo: :salida, cantidad: cantidad, detalle: detalle}
        actualizado = %{recurso | cantidad: recurso.cantidad - cantidad, historial: [mov | recurso.historial]}
        nuevo_estado = Map.put(state, codigo, actualizado)
        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, actualizado}, nuevo_estado}
    end
  end

  def handle_call({:salida, _codigo, _cantidad, _detalle}, _from, state) do
    {:reply, {:error, :cantidad_debe_ser_positiva}, state}
  end

  @impl true
  def handle_call({:asignar, necesidad_id, recurso_o_tipo, cantidad}, _from, state)
      when is_integer(cantidad) and cantidad > 0 do
    with {:ok, recurso} <- buscar_recurso_disponible(state, recurso_o_tipo, cantidad),
         {:ok, necesidad_act} <- NecesidadesServer.aplicar_asignacion(necesidad_id, cantidad) do
      mov = %{
        fecha: Util.fecha_actual(),
        tipo: :salida,
        cantidad: cantidad,
        detalle: "Asignado a necesidad #{necesidad_id}"
      }

      recurso_act = %{
        recurso
        | cantidad: recurso.cantidad - cantidad,
          historial: [mov | recurso.historial]
      }

      nuevo_estado = Map.put(state, recurso.codigo, recurso_act)
      Persistencia.guardar(@archivo, nuevo_estado)
      {:reply, {:ok, %{recurso: recurso_act, necesidad: necesidad_act}}, nuevo_estado}
    else
      error -> {:reply, error, state}
    end
  end

  def handle_call({:asignar, _nec, _rec, _cant}, _from, state) do
    {:reply, {:error, :cantidad_debe_ser_positiva}, state}
  end

  @impl true
  def handle_call({:transferir, codigo, origen, destino, cantidad}, _from, state)
      when is_integer(cantidad) and cantidad > 0 do
    case Map.get(state, codigo) do
      nil ->
        {:reply, {:error, :recurso_no_encontrado}, state}

      %Recurso{ubicacion: ub} when ub != origen ->
        {:reply, {:error, :ubicacion_origen_no_coincide}, state}

      %Recurso{cantidad: disp} when disp < cantidad ->
        {:reply, {:error, :inventario_insuficiente}, state}

      recurso_origen ->
        mov_out = %{
          fecha: Util.fecha_actual(),
          tipo: :transferencia_salida,
          cantidad: cantidad,
          detalle: "Transferido de #{origen} hacia #{destino}"
        }

        origen_act = %{
          recurso_origen
          | cantidad: recurso_origen.cantidad - cantidad,
            historial: [mov_out | recurso_origen.historial]
        }

        codigo_destino = "#{codigo}-#{destino}"

        mov_in = %{
          fecha: Util.fecha_actual(),
          tipo: :transferencia_entrada,
          cantidad: cantidad,
          detalle: "Recibido desde #{origen}"
        }

        destino_act =
          case Map.get(state, codigo_destino) do
            nil ->
              %Recurso{
                codigo: codigo_destino,
                nombre: recurso_origen.nombre,
                categoria: recurso_origen.categoria,
                cantidad: cantidad,
                unidad: recurso_origen.unidad,
                ubicacion: destino,
                historial: [mov_in]
              }

            existente ->
              %{
                existente
                | cantidad: existente.cantidad + cantidad,
                  historial: [mov_in | existente.historial]
              }
          end

        nuevo_estado =
          state
          |> Map.put(codigo, origen_act)
          |> Map.put(codigo_destino, destino_act)

        Persistencia.guardar(@archivo, nuevo_estado)
        {:reply, {:ok, %{origen: origen_act, destino: destino_act}}, nuevo_estado}
    end
  end

  def handle_call({:transferir, _c, _o, _d, _cant}, _from, state) do
    {:reply, {:error, :cantidad_debe_ser_positiva}, state}
  end

  @impl true
  def handle_call({:listar, filtros}, _from, state) do
    lista =
      state
      |> Map.values()
      |> Enum.filter(fn rec ->
        Enum.all?(filtros, fn {k, v} -> Map.get(rec, k) == v end)
      end)

    {:reply, lista, state}
  end

  @impl true
  def handle_call({:criticos, umbral}, _from, state) do
    criticos =
      state
      |> Map.values()
      |> Enum.filter(fn rec -> rec.cantidad <= umbral end)

    {:reply, criticos, state}
  end

  # Busca por código exacto o por categoría/nombre con stock suficiente
  defp buscar_recurso_disponible(state, criterio, cantidad) do
    criterio_str = Util.normalizar(to_string(criterio))

    candidatos =
      state
      |> Map.values()
      |> Enum.filter(fn r ->
        Util.normalizar(r.codigo) == criterio_str or
          Util.normalizar(to_string(r.categoria)) == criterio_str or
          Util.normalizar(r.nombre) == criterio_str
      end)

    cond do
      candidatos == [] ->
        {:error, :recurso_no_encontrado}

      true ->
        case Enum.find(candidatos, fn r -> r.cantidad >= cantidad end) do
          nil -> {:error, :inventario_insuficiente}
          recurso -> {:ok, recurso}
        end
    end
  end
end
