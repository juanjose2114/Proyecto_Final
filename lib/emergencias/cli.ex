defmodule Emergencias.CLI do
  @moduledoc """
  Interfaz de consola interactiva y guiada para el Sistema de Emergencias.
  """

  alias Emergencias.Util

  def iniciar do
    IO.puts("\n=======================================================")
    IO.puts("  SISTEMA DE COORDINACIÓN DE EMERGENCIAS (ELIXIR/OTP)")
    IO.puts("=======================================================")
    bucle(nil)
  end

  # 1. Sin sesión activa: guía paso a paso para conectarse o registrarse
  defp bucle(nil) do
    IO.puts("\n--- INICIO DE SESIÓN / REGISTRO AUTOMÁTICO ---")
    IO.puts("(Responde cada dato o escribe 'exit' para salir)\n")

    entrada = pedir("Usuario (ej. laura): ")

    cond do
      entrada in ["exit", "salir"] ->
        IO.puts("Saliendo del sistema...")
        :ok

      String.starts_with?(entrada, "connect ") ->
        nuevo_usuario = ejecutar(OptionParser.split(entrada), nil)
        bucle(nuevo_usuario)

      entrada == "" ->
        bucle(nil)

      true ->
        password = pedir("Contraseña: ")
        rol = pedir("Rol (ciudadano / voluntario / coordinador / administrador): ")
        zona = pedir("Zona principal (ej. centro, norte, sur): ")

        nuevo_usuario = ejecutar(["connect", entrada, password, rol, zona], nil)
        bucle(nuevo_usuario)
    end
  end

  # 2. Con sesión activa: muestra opciones numeradas y pide cada campo
  defp bucle(usuario) do
    mostrar_menu(usuario)
    opcion = pedir("\nElige una opción (0-14) o escribe un comando directo: ")

    case opcion do
      "" ->
        bucle(usuario)

      op when op in ["exit", "salir"] ->
        IO.puts("Cerrando consola...")
        :ok

      _ ->
        tokens = construir_comando_guiado(opcion)
        nuevo_usuario = ejecutar(tokens, usuario)
        bucle(nuevo_usuario)
    end
  end

  defp mostrar_menu(usuario) do
    IO.puts("""

    -------------------------------------------------------
    Sesión activa: #{usuario.username} | Rol: #{usuario.rol} | Zona: #{usuario.zona_principal}
    -------------------------------------------------------
     1. Registrar zona afectada
     2. Consultar zona
     3. Registrar necesidad de ayuda
     4. Listar necesidades (priorizadas)
     5. Registrar recurso en inventario
     6. Asignar recurso a una necesidad
     7. Reportar persona afectada
     8. Enviar mensaje a familiar
     9. Consultar mensajes de familiar
    10. Registrar albergue
    11. Ingresar persona a albergue
    12. Reportar mascota (perdida / encontrada)
    13. Buscar coincidencias de mascotas (matching)
     0. Ver resumen global (summary)
    14. Cerrar sesión (disconnect) | 'exit' para salir
    -------------------------------------------------------
    """)
  end

  # --- Guía campo por campo según la opción elegida ---
  defp construir_comando_guiado("1") do
    IO.puts("\n[Registrar Zona]")
    cod = pedir("Código de zona (ej. Z01): ")
    nombre = pedir("Nombre de la zona (ej. Centro): ")
    nivel = pedir("Nivel de afectación (critico / alto / medio / bajo): ")
    afectados = pedir("Número estimado de afectados (ej. 120): ")
    ["register_zone", cod, nombre, nivel, afectados]
  end

  defp construir_comando_guiado("2") do
    cod = pedir("Código de zona a consultar (ej. Z01): ")
    ["check_zone", cod]
  end

  defp construir_comando_guiado("3") do
    IO.puts("\n[Registrar Necesidad]")
    tipo = pedir("Tipo (agua / alimentos / medicamentos / refugio / rescate): ")
    cant = pedir("Cantidad requerida (ej. 30): ")
    prio = pedir("Prioridad (critica / alta / media / baja): ")
    zona = pedir("Zona (ej. centro): ")
    desc = pedir("Descripción breve: ")
    ["register_need", tipo, cant, prio, zona, desc]
  end

  defp construir_comando_guiado("4"), do: ["list_needs"]

  defp construir_comando_guiado("5") do
    IO.puts("\n[Registrar Recurso]")
    cod = pedir("Código del recurso (ej. R001): ")
    tipo = pedir("Tipo/Categoría (ej. agua, alimentos, cobijas): ")
    cant = pedir("Cantidad disponible (ej. 50): ")
    unidad = pedir("Unidad de medida (ej. litros, cajas, unidades): ")
    ubic = pedir("Ubicación / Centro de acopio (ej. centro_acopio_1): ")
    ["register_resource", cod, tipo, cant, unidad, ubic]
  end

  defp construir_comando_guiado("6") do
    IO.puts("\n[Asignar Recurso a Necesidad]")
    need_id = pedir("ID de la necesidad (ej. N001): ")
    tipo = pedir("Tipo de recurso (ej. agua): ")
    cant = pedir("Cantidad a asignar (ej. 30): ")
    ["assign_resource", need_id, tipo, cant]
  end

  defp construir_comando_guiado("7") do
    IO.puts("\n[Reportar Persona Afectada]")
    doc = pedir("Documento de identidad: ")
    nombre = pedir("Nombre completo: ")
    zona = pedir("Zona donde se encuentra: ")
    estado = pedir("Estado (reportada / localizada / en_albergue / reunificada): ")
    ["report_person", doc, nombre, zona, estado]
  end

  defp construir_comando_guiado("8") do
    IO.puts("\n[Enviar Mensaje Familiar]")
    doc = pedir("Documento del destinatario: ")
    msg = pedir("Mensaje para el familiar: ")
    ["send_family_message", doc, msg]
  end

  defp construir_comando_guiado("9") do
    doc = pedir("Documento del familiar a consultar: ")
    ["list_family_messages", doc]
  end

  defp construir_comando_guiado("10") do
    IO.puts("\n[Registrar Albergue]")
    cod = pedir("Código del albergue (ej. A01): ")
    nombre = pedir("Nombre del albergue (ej. Albergue Norte): ")
    zona = pedir("Zona: ")
    cap = pedir("Capacidad máxima (ej. 50): ")
    ["register_shelter", cod, nombre, zona, cap]
  end

  defp construir_comando_guiado("11") do
    IO.puts("\n[Ingreso a Albergue]")
    cod = pedir("Código del albergue (ej. A01): ")
    doc = pedir("Documento de la persona: ")
    ["register_entry", cod, doc]
  end

  defp construir_comando_guiado("12") do
    IO.puts("\n[Reportar Mascota]")
    tipo = pedir("Tipo de reporte (lost / found): ")
    especie = pedir("Especie (perro / gato / otro): ")
    nombre = pedir("Nombre (o 'desconocido'): ")
    color = pedir("Color: ")
    tamano = pedir("Tamaño (pequeno / mediana / grande): ")
    zona = pedir("Zona: ")
    contacto = pedir("Teléfono de contacto: ")
    ["report_pet", tipo, especie, nombre, color, tamano, zona, contacto]
  end

  defp construir_comando_guiado("13"), do: ["match_pets"]
  defp construir_comando_guiado("0"), do: ["summary"]
  defp construir_comando_guiado("14"), do: ["disconnect"]

  defp construir_comando_guiado(comando_texto) do
    OptionParser.split(comando_texto)
  end

  # --- Ejecución de comandos contra la fachada Emergencias ---
  defp ejecutar(["connect", user, pass, rol, zona], _usuario) do
    case Emergencias.connect(user, pass, a_atomo(rol), zona) do
      {:ok, u} ->
        Util.mostrar_mensaje("Conectado como #{u.username} (#{u.rol})")
        u

      {:error, motivo} ->
        Util.mostrar_error("Error al conectar: #{inspect(motivo)}")
        nil
    end
  end

  defp ejecutar(["disconnect"], nil) do
    Util.mostrar_error("No hay ninguna sesión activa.")
    nil
  end

  defp ejecutar(["disconnect"], usuario) do
    Emergencias.disconnect(usuario.username)
    Util.mostrar_mensaje("Sesión cerrada para #{usuario.username}.")
    nil
  end

  defp ejecutar(["register_zone", cod, nombre, nivel, afectados], usuario) do
    with {:ok, cant} <- parse_int(afectados) do
      Emergencias.registrar_zona(usuario.username, cod, nombre, a_atomo(nivel), cant)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["check_zone", cod], usuario) do
    Emergencias.consultar_zona(usuario.username, cod)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["register_need", tipo, cant, prio, zona, desc], usuario) do
    with {:ok, c} <- parse_int(cant) do
      Emergencias.registrar_necesidad(usuario.username, a_atomo(tipo), c, a_atomo(prio), zona, desc)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["list_needs"], usuario) do
    Emergencias.listar_necesidades(usuario.username, [])
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["assign_resource", need_id, tipo, cant], usuario) do
    with {:ok, c} <- parse_int(cant) do
      Emergencias.asignar_recurso(usuario.username, need_id, a_atomo(tipo), c)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["register_resource", cod, tipo, cant, unidad, ubic], usuario) do
    with {:ok, c} <- parse_int(cant) do
      Emergencias.registrar_recurso(usuario.username, cod, tipo, a_atomo(tipo), c, unidad, ubic)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["list_resources"], usuario) do
    Emergencias.listar_recursos(usuario.username, [])
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["transfer_resource", cod, origen, destino, cant], usuario) do
    with {:ok, c} <- parse_int(cant) do
      Emergencias.transferir_recurso(usuario.username, cod, origen, destino, c)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["report_person", doc, nombre, zona, estado], usuario) do
    Emergencias.reportar_persona(usuario.username, doc, nombre, 0, zona, a_atomo(estado))
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["find_person", doc], usuario) do
    Emergencias.buscar_persona(usuario.username, doc)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["send_family_message", doc, msg], usuario) do
    Emergencias.enviar_mensaje_familiar(usuario.username, doc, msg)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["list_family_messages", doc], usuario) do
    Emergencias.listar_mensajes_familiares(usuario.username, doc)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["report_pet", tipo, especie, nombre, color, tamano, zona, contacto], usuario) do
    tipo_atom = if tipo in ["lost", "perdida"], do: :perdida, else: :encontrada

    Emergencias.reportar_mascota(
      usuario.username,
      tipo_atom,
      especie,
      nombre,
      "#{color}, #{tamano}",
      color,
      tamano,
      zona,
      contacto
    )
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["match_pets"], usuario) do
    Emergencias.buscar_coincidencias_mascotas(usuario.username)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["confirm_match", id_perdida, id_encontrada], usuario) do
    Emergencias.confirmar_coincidencia_mascota(usuario.username, id_perdida, id_encontrada)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["register_shelter", cod, nombre, zona, cap], usuario) do
    with {:ok, c} <- parse_int(cap) do
      Emergencias.registrar_albergue(usuario.username, cod, nombre, zona, c)
      |> mostrar_resultado()
    end

    usuario
  end

  defp ejecutar(["check_shelter", cod], usuario) do
    Emergencias.consultar_albergue(usuario.username, cod)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["register_entry", cod, doc], usuario) do
    Emergencias.registrar_ingreso_albergue(usuario.username, cod, doc)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["register_exit", cod, doc], usuario) do
    Emergencias.registrar_salida_albergue(usuario.username, cod, doc)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["shelter_report"], usuario) do
    Emergencias.reporte_ocupacion_albergues(usuario.username)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["summary"], usuario) do
    Emergencias.resumen_global(usuario.username)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["critical_resources"], usuario) do
    Emergencias.recursos_criticos(usuario.username)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(["pending_needs"], usuario) do
    Emergencias.necesidades_pendientes(usuario.username)
    |> mostrar_resultado()

    usuario
  end

  defp ejecutar(_, usuario) do
    Util.mostrar_error("Opción o comando no válido. Elige un número del menú (0-14).")
    usuario
  end

  # --- Auxiliares ---
  defp pedir(etiqueta) do
    etiqueta
    |> IO.gets()
    |> to_string()
    |> String.trim()
  end

  defp a_atomo(texto) do
    texto |> String.trim() |> String.downcase() |> String.to_atom()
  end

  defp parse_int(texto) do
    case Integer.parse(String.trim(texto)) do
      {num, ""} ->
        {:ok, num}

      _ ->
        Util.mostrar_error("Se esperaba un número entero válido.")
        :error
    end
  end

  defp mostrar_resultado({:ok, res}) do
    Util.mostrar_mensaje("OK => #{inspect(res, pretty: true)}")
  end

  defp mostrar_resultado({:error, motivo}) do
    Util.mostrar_error("ERROR => #{inspect(motivo)}")
  end
end
