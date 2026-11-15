defmodule Emergencias do
  @moduledoc """
  Fachada principal del Sistema Distribuido de Coordinación y Gestión de Emergencias.
  Valida sesión activa, controla permisos según el rol del usuario, registra
  cada operación en la bitácora y delega la ejecución a los procesos GenServer.
  """

  alias Emergencias.Servers.{
    UsuariosServer,
    ZonasServer,
    NecesidadesServer,
    RecursosServer,
    PersonasServer,
    MascotasServer,
    AlberguesServer
  }

  # Matriz de permisos por rol
  @permisos %{
    administrador: :all,
    coordinador: [
      :gestion_zonas,
      :gestion_necesidades,
      :gestion_recursos,
      :asignar_recursos,
      :transferir_recursos,
      :gestion_personas,
      :mensajes_familiares,
      :gestion_mascotas,
      :gestion_albergues,
      :consultas
    ],
    voluntario: [
      :gestion_necesidades,
      :gestion_personas,
      :mensajes_familiares,
      :gestion_mascotas,
      :gestion_albergues,
      :consultas
    ],
    ciudadano: [
      :gestion_necesidades,
      :gestion_personas,
      :mensajes_familiares,
      :gestion_mascotas,
      :consultas
    ]
  }

  # ===================================================================
  # 1. GESTIÓN DE USUARIOS Y SESIÓN
  # ===================================================================

  def connect(username, password, rol \\ :ciudadano, zona \\ "general", nombre \\ nil) do
    UsuariosServer.connect(username, password, rol, zona, nombre)
  end

  def disconnect(username) do
    UsuariosServer.disconnect(username)
  end

  # ===================================================================
  # 2. GESTIÓN DE ZONAS AFECTADAS
  # ===================================================================

  def registrar_zona(actor, codigo, nombre, nivel, afectados \\ 0) do
    ejecutar_con_permiso(actor, :gestion_zonas, "Registró zona #{codigo}", fn ->
      ZonasServer.registrar_zona(codigo, nombre, nivel, afectados)
    end)
  end

  def agregar_sector(actor, codigo_zona, sector) do
    ejecutar_con_permiso(actor, :gestion_zonas, "Agregó sector a zona #{codigo_zona}", fn ->
      ZonasServer.agregar_sector(codigo_zona, sector)
    end)
  end

  def consultar_zona(actor, codigo) do
    ejecutar_con_permiso(actor, :consultas, "Consultó zona #{codigo}", fn ->
      ZonasServer.consultar_zona(codigo)
    end)
  end

  # ===================================================================
  # 3. GESTIÓN DE NECESIDADES PUNTUALES
  # ===================================================================

  def registrar_necesidad(actor, tipo, cantidad, prioridad, zona, descripcion) do
    ejecutar_con_permiso(actor, :gestion_necesidades, "Registró necesidad de #{tipo}", fn ->
      NecesidadesServer.registrar_necesidad(tipo, cantidad, prioridad, zona, descripcion, actor)
    end)
  end

  def listar_necesidades(actor, filtros \\ []) do
    ejecutar_con_permiso(actor, :consultas, "Listó necesidades", fn ->
      {:ok, NecesidadesServer.listar_necesidades(filtros)}
    end)
  end

  def necesidades_pendientes(actor) do
    listar_necesidades(actor, estado: :pendiente)
  end

  # ===================================================================
  # 4. GESTIÓN DE RECURSOS E INVENTARIO
  # ===================================================================

  def registrar_recurso(actor, codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    ejecutar_con_permiso(actor, :gestion_recursos, "Registró recurso #{codigo}", fn ->
      RecursosServer.registrar_recurso(codigo, nombre, categoria, cantidad, unidad, ubicacion)
    end)
  end

  def asignar_recurso(actor, necesidad_id, recurso_o_tipo, cantidad) do
    ejecutar_con_permiso(
      actor,
      :asignar_recursos,
      "Asignó #{cantidad} de #{recurso_o_tipo} a #{necesidad_id}",
      fn -> RecursosServer.asignar_recurso(necesidad_id, recurso_o_tipo, cantidad) end
    )
  end

  def transferir_recurso(actor, codigo, origen, destino, cantidad) do
    ejecutar_con_permiso(
      actor,
      :transferir_recursos,
      "Transfirió #{cantidad} de #{codigo} (#{origen} -> #{destino})",
      fn -> RecursosServer.transferir_recurso(codigo, origen, destino, cantidad) end
    )
  end

  def listar_recursos(actor, filtros \\ []) do
    ejecutar_con_permiso(actor, :consultas, "Consultó inventario de recursos", fn ->
      {:ok, RecursosServer.listar_recursos(filtros)}
    end)
  end

  def recursos_criticos(actor, umbral \\ 25) do
    ejecutar_con_permiso(actor, :consultas, "Consultó recursos críticos", fn ->
      {:ok, RecursosServer.recursos_criticos(umbral)}
    end)
  end

  # ===================================================================
  # 5. PERSONAS AFECTADAS Y MENSAJES ENTRE FAMILIARES
  # ===================================================================

  def reportar_persona(actor, documento, nombre, zona, estado \\ :reportada, edad \\ 0) do
    ejecutar_con_permiso(actor, :gestion_personas, "Reportó persona #{documento}", fn ->
      PersonasServer.reportar_persona(documento, nombre, zona, estado, edad)
    end)
  end

  def buscar_persona(actor, criterio) do
    ejecutar_con_permiso(actor, :consultas, "Buscó persona (#{inspect(criterio)})", fn ->
      {:ok, PersonasServer.buscar_personas(criterio)}
    end)
  end

  def enviar_mensaje_familiar(actor, destinatario_doc, contenido) do
    ejecutar_con_permiso(
      actor,
      :mensajes_familiares,
      "Envió mensaje familiar a #{destinatario_doc}",
      fn -> PersonasServer.enviar_mensaje(actor, destinatario_doc, contenido) end
    )
  end

  def listar_mensajes_familiares(actor, destinatario_doc) do
    ejecutar_con_permiso(actor, :consultas, "Consultó mensajes de #{destinatario_doc}", fn ->
      {:ok, PersonasServer.listar_mensajes(destinatario_doc)}
    end)
  end

  def marcar_mensaje_familiar(actor, id_mensaje, estado) do
    ejecutar_con_permiso(actor, :mensajes_familiares, "Marcó mensaje #{id_mensaje} como #{estado}", fn ->
      PersonasServer.marcar_mensaje(id_mensaje, estado)
    end)
  end

  # ===================================================================
  # 6. MASCOTAS PERDIDAS Y ENCONTRADAS
  # ===================================================================

  def reportar_mascota(actor, tipo, especie, nombre, caract, color, tamano, zona, contacto) do
    ejecutar_con_permiso(actor, :gestion_mascotas, "Reportó mascota (#{tipo})", fn ->
      MascotasServer.reportar_mascota(tipo, especie, nombre, caract, color, tamano, zona, contacto)
    end)
  end

  def buscar_coincidencias_mascotas(actor) do
    ejecutar_con_permiso(actor, :consultas, "Ejecutó matching de mascotas", fn ->
      {:ok, MascotasServer.buscar_coincidencias()}
    end)
  end

  def confirmar_coincidencia_mascota(actor, perdida_id, encontrada_id) do
    ejecutar_con_permiso(
      actor,
      :gestion_mascotas,
      "Confirmó match #{perdida_id} <-> #{encontrada_id}",
      fn -> MascotasServer.confirmar_coincidencia(perdida_id, encontrada_id) end
    )
  end

  # ===================================================================
  # 7. GESTIÓN DE ALBERGUES
  # ===================================================================

  def registrar_albergue(actor, codigo, nombre, zona, capacidad_maxima) do
    ejecutar_con_permiso(actor, :gestion_albergues, "Registró albergue #{codigo}", fn ->
      AlberguesServer.registrar_albergue(codigo, nombre, zona, capacidad_maxima)
    end)
  end

  def consultar_albergue(actor, codigo) do
    ejecutar_con_permiso(actor, :consultas, "Consultó albergue #{codigo}", fn ->
      AlberguesServer.consultar_albergue(codigo)
    end)
  end

  def registrar_ingreso_albergue(actor, codigo, documento) do
    ejecutar_con_permiso(
      actor,
      :gestion_albergues,
      "Ingresó persona #{documento} en albergue #{codigo}",
      fn -> AlberguesServer.registrar_ingreso(codigo, documento) end
    )
  end

  def registrar_salida_albergue(actor, codigo, documento) do
    ejecutar_con_permiso(
      actor,
      :gestion_albergues,
      "Registró salida de #{documento} en albergue #{codigo}",
      fn -> AlberguesServer.registrar_salida(codigo, documento) end
    )
  end

  def reporte_ocupacion_albergues(actor) do
    ejecutar_con_permiso(actor, :consultas, "Consultó reporte de ocupación de albergues", fn ->
      {:ok, AlberguesServer.reporte_ocupacion()}
    end)
  end

  # ===================================================================
  # 8. RESUMEN GLOBAL DE LA EMERGENCIA (summary)
  # ===================================================================

  def resumen_global(actor) do
    ejecutar_con_permiso(actor, :consultas, "Consultó resumen global (summary)", fn ->
      %{personas: personas, mensajes: mensajes} = PersonasServer.resumen_personas()

      resumen = %{
        zonas: ZonasServer.listar_zonas(),
        necesidades_pendientes: NecesidadesServer.listar_necesidades(estado: :pendiente),
        total_necesidades: length(NecesidadesServer.listar_necesidades()),
        recursos: RecursosServer.listar_recursos(),
        personas_reportadas: length(personas),
        personas_localizadas: Enum.count(personas, &(&1.estado in [:localizada, :en_albergue, :reunificada])),
        total_mensajes: length(mensajes),
        coincidencias_mascotas: MascotasServer.buscar_coincidencias(),
        albergues: AlberguesServer.reporte_ocupacion()
      }

      {:ok, resumen}
    end)
  end

  # ===================================================================
  # CONTROL DE AUTORIZACIÓN Y BITÁCORA
  # ===================================================================

  defp ejecutar_con_permiso(nil, _permiso, _descripcion, _funcion) do
    {:error, :sesion_no_iniciada}
  end

  defp ejecutar_con_permiso(username, permiso, descripcion, funcion) do
    with {:ok, usuario} <- UsuariosServer.obtener_usuario(username),
         :ok <- verificar_sesion(usuario),
         :ok <- verificar_rol(usuario.rol, permiso) do
      resultado = funcion.()
      UsuariosServer.registrar_actividad(username, descripcion)
      resultado
    end
  end

  defp verificar_sesion(%{conectado?: true}), do: :ok
  defp verificar_sesion(_), do: {:error, :usuario_desconectado}

  defp verificar_rol(rol, permiso) do
    case Map.get(@permisos, rol) do
      :all -> :ok
      lista when is_list(lista) -> if permiso in lista, do: :ok, else: {:error, :permiso_denegado_para_rol}
      _ -> {:error, :rol_no_autorizado}
    end
  end
end
