def iniciar do
  IO.puts("\n=======================================================")
  IO.puts("  SISTEMA DE COORDINACIÓN DE EMERGENCIAS (ELIXIR/OTP)")
  IO.puts("=======================================================")
  bucle(nil)
end

# 1. Si NO hay sesión activa, guía al usuario paso a paso para conectarse
defp bucle(nil) do
  IO.puts("\n--- INICIO DE SESIÓN / REGISTRO AUTOMÁTICO ---")
  IO.puts("(Escribe los datos que se solicitan o pega un comando directo)\n")

  entrada = pedir("Usuario (o 'exit' para salir): ")

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

# 2. Cuando YA hay sesión activa, muestra menú numerado y guía campo por campo
defp bucle(usuario) do
  mostrar_menu(usuario)
  opcion = pedir("\nElige una opción (1-14) o escribe un comando directo: ")

  case opcion do
    "" ->
      bucle(usuario)

    op when op in ["exit", "salir", "14"] ->
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
  14. Cerrar sesión (disconnect) / 'exit' para salir
  -------------------------------------------------------
  """)
end

# Pide cada campo según el número elegido y arma la lista que ya entiende tu ejecutar/2
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

# Si el usuario escribió un comando directo en texto en vez de un número, lo parsea normal
defp construir_comando_guiado(comando_texto) do
  OptionParser.split(comando_texto)
end

defp pedir(etiqueta) do
  etiqueta
  |> IO.gets()
  |> to_string()
  |> String.trim()
end
