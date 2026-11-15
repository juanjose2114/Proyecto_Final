defmodule Emergencias.CLI do
  @moduledoc """
  Interfaz de línea de comandos (CLI) para operar el sistema de emergencias.
  Soporta todos los comandos de referencia y mantiene el usuario autenticado en la sesión.
  """

  alias Emergencias.Util

  @doc "Inicia el ciclo interactivo en consola."
  def iniciar do
    Util.mostrar_mensaje("""
    ====================================================================
      SISTEMA DISTRIBUIDO DE GESTIÓN DE EMERGENCIAS (ELIXIR / OTP)
      Escriba 'help' para ver los comandos disponibles o 'exit' para salir.
    ====================================================================
    """)

    loop(nil)
  end

  defp loop(usuario_actual) do
    prompt = if usuario_actual, do: "[#{usuario_actual}]> ", else: "[sin_sesion]> "
    linea = Util.ingresar(prompt, :texto)

    case linea do
      "" ->
        loop(usuario_actual)

      "exit" ->
        Util.mostrar_mensaje("Cerrando consola de emergencias...")
        :ok

      "salir" ->
        Util.mostrar_mensaje("Cerrando consola de emergencias...")
        :ok

      comando ->
        nuevo_usuario = procesar_comando(comando, usuario_actual)
        loop(nuevo_usuario)
    end
  end

  @doc "Procesa una línea de comando y retorna el usuario activo tras la ejecución."
  def procesar_comando(linea, usuario_actual) do
    tokens = OptionParser.split(linea)

    case tokens do
      ["help"] ->
        mostrar_ayuda()
        usuario_actual

      # --- Usuarios ---
      ["connect", user, pass] ->
        ejecutar_connect(user, pass, :ciudadano, "general", usuario_actual)

      ["connect", user, pass, rol, zona] ->
        ejecutar_connect(user, pass, String.to_atom(rol), zona, usuario_actual)

      ["disconnect"] ->
        case usuario_actual do
          nil ->
            Util.mostrar_error("No hay ninguna sesión activa.")
            nil

          user ->
            mostrar_resultado(Emergencias.disconnect(user))
            nil
        end

      # --- Zonas ---
      ["register_zone", codigo, nombre, nivel] ->
        mostrar_resultado(Emergencias.registrar_zona(usuario_actual, codigo, nombre, String.to_atom(nivel)))
        usuario_actual

      ["register_zone", codigo, nombre, nivel, afectados] ->
        mostrar_resultado(
          Emergencias.registrar_zona(usuario_actual, codigo, nombre, String.to_atom(nivel), String.to_integer(afectados))
        )
        usuario_actual

      ["check_zone", codigo] ->
        mostrar_resultado(Emergencias.consultar_zona(usuario_actual, codigo))
        usuario_actual

      # --- Necesidades ---
      ["register_need", tipo, cant, prioridad, zona, desc] ->
        mostrar_resultado(
          Emergencias.registrar_necesidad(
            usuario_actual,
            String.to_atom(tipo),
            String.to_integer(cant),
            String.to_atom(prioridad),
            zona,
            desc
          )
        )
        usuario_actual

      ["list_needs" | filtros_raw] ->
        filtros = parsear_filtros(filtros_raw, [:tipo, :prioridad, :estado])
        mostrar_resultado(Emergencias.listar_necesidades(usuario_actual, filtros))
        usuario_actual

      ["pending_needs"] ->
        mostrar_resultado(Emergencias.necesidades_pendientes(usuario_actual))
        usuario_actual

      # --- Recursos ---
      ["register_resource", cod, nombre, cant, unidad, ubicacion] ->
        mostrar_resultado(
          Emergencias.registrar_recurso(
            usuario_actual,
            cod,
            nombre,
            String.to_atom(Util.normalizar(nombre)),
            String.to_integer(cant),
            unidad,
            ubicacion
          )
        )
        usuario_actual

      ["assign_resource", need_id, recurso_o_tipo, cant] ->
        mostrar_resultado(
          Emergencias.asignar_recurso(usuario_actual, need_id, recurso_o_tipo, String.to_integer(cant))
        )
        usuario_actual

      ["list_resources" | filtros_raw] ->
        filtros = parsear_filtros(filtros_raw, [:categoria])
        mostrar_resultado(Emergencias.listar_recursos(usuario_actual, filtros))
        usuario_actual

      ["transfer_resource", cod, origen, destino, cant] ->
        mostrar_resultado(
          Emergencias.transferir_recurso(usuario_actual, cod, origen, destino, String.to_integer(cant))
        )
        usuario_actual

      ["critical_resources"] ->
        mostrar_resultado(Emergencias.recursos_criticos(usuario_actual))
        usuario_actual

      # --- Personas y Familiares ---
      ["report_person", doc, nombre, zona, estado] ->
        mostrar_resultado(
          Emergencias.reportar_persona(usuario_actual, doc, nombre, zona, String.to_atom(estado))
        )
        usuario_actual

      ["find_person", criterio] ->
        mostrar_resultado(Emergencias.buscar_persona(usuario_actual, criterio))
        usuario_actual

      ["send_family_message", doc, contenido] ->
        mostrar_resultado(Emergencias.enviar_mensaje_familiar(usuario_actual, doc, contenido))
        usuario_actual

      ["list_family_messages", doc] ->
        mostrar_resultado(Emergencias.listar_mensajes_familiares(usuario_actual, doc))
        usuario_actual

      # --- Mascotas ---
      ["report_pet", tipo_raw, especie, nombre, color, tamano, zona, contacto] ->
        tipo = normalizar_tipo_mascota(tipo_raw)

        mostrar_resultado(
          Emergencias.reportar_mascota(
            usuario_actual,
            tipo,
            especie,
            nombre,
            "#{color}, #{tamano}",
            color,
            String.to_atom(Util.normalizar(tamano)),
            zona,
            contacto
          )
        )
        usuario_actual

      ["match_pets"] ->
        mostrar_resultado(Emergencias.buscar_coincidencias_mascotas(usuario_actual))
        usuario_actual

      ["confirm_match", perdida_id, encontrada_id] ->
        mostrar_resultado(Emergencias.confirmar_coincidencia_mascota(usuario_actual, perdida_id, encontrada_id))
        usuario_actual

      # --- Albergues ---
      ["register_shelter", cod, nombre, zona, cap] ->
        mostrar_resultado(
          Emergencias.registrar_albergue(usuario_actual, cod, nombre, zona, String.to_integer(cap))
        )
        usuario_actual

      ["check_shelter", cod] ->
        mostrar_resultado(Emergencias.consultar_albergue(usuario_actual, cod))
        usuario_actual

      ["register_entry", cod, doc] ->
        mostrar_resultado(Emergencias.registrar_ingreso_albergue(usuario_actual, cod, doc))
        usuario_actual

      ["register_exit", cod, doc] ->
        mostrar_resultado(Emergencias.registrar_salida_albergue(usuario_actual, cod, doc))
        usuario_actual

      ["shelter_report"] ->
        mostrar_resultado(Emergencias.reporte_ocupacion_albergues(usuario_actual))
        usuario_actual

      # --- Resumen global ---
      ["summary"] ->
        mostrar_resultado(Emergencias.resumen_global(usuario_actual))
        usuario_actual

      _ ->
        Util.mostrar_error("Comando no reconocido o parámetros incompletos. Escriba 'help'.")
        usuario_actual
    end
  rescue
    e in ArgumentError ->
      Util.mostrar_error("Formato numérico inválido: #{Exception.message(e)}")
      usuario_actual
  end

  defp ejecutar_connect(user, pass, rol, zona, usuario_actual) do
    case Emergencias.connect(user, pass, rol, zona) do
      {:ok, u} ->
        Util.mostrar_mensaje("Conectado como #{u.username} (rol: #{u.rol}, zona: #{u.zona_principal})")
        u.username

      {:error, razon} ->
        Util.mostrar_error(inspect(razon))
        usuario_actual
    end
  end

  defp normalizar_tipo_mascota("lost"), do: :perdida
  defp normalizar_tipo_mascota("perdida"), do: :perdida
  defp normalizar_tipo_mascota("found"), do: :encontrada
  defp normalizar_tipo_mascota("encontrada"), do: :encontrada
  defp normalizar_tipo_mascota(otro), do: String.to_atom(otro)

  defp parsear_filtros(tokens, claves_atomo) do
    Enum.flat_map(tokens, fn token ->
      case String.split(token, "=", parts: 2) do
        [k, v] ->
          clave = String.to_atom(k)
          valor = if clave in claves_atomo, do: String.to_atom(v), else: v
          [{clave, valor}]

        _ ->
          []
      end
    end)
  end

  defp mostrar_resultado({:ok, data}) do
    IO.inspect(data, pretty: true, label: "OK")
  end

  defp mostrar_resultado({:error, razon}) do
    Util.mostrar_error(inspect(razon))
  end

  defp mostrar_ayuda do
    Util.mostrar_mensaje("""
    Comandos disponibles:
      connect <usuario> <password> [<rol> <zona>]
      disconnect
      register_zone <codigo> <nombre> <nivel> [<afectados>]
      check_zone <codigo>
      register_need <tipo> <cantidad> <prioridad> <zona> "<descripcion>"
      list_needs [zona=<z> prioridad=<p> estado=<e>]
      pending_needs
      register_resource <codigo> <nombre> <cantidad> <unidad> <ubicacion>
      assign_resource <need_id> <recurso_o_tipo> <cantidad>
      list_resources
      transfer_resource <codigo> <origen> <destino> <cantidad>
      critical_resources
      report_person <documento> "<nombre>" <zona> <estado>
      find_person <documento_o_nombre>
      send_family_message <documento> "<mensaje>"
      list_family_messages <documento>
      report_pet <lost|found> <especie> "<nombre>" <color> <tamano> <zona> <contacto>
      match_pets
      confirm_match <perdida_id> <encontrada_id>
      register_shelter <codigo> "<nombre>" <zona> <capacidad>
      check_shelter <codigo>
      register_entry <codigo_albergue> <documento>
      register_exit <codigo_albergue> <documento>
      shelter_report
      summary
    """)
  end
end
