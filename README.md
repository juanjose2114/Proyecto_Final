Proyecto_Final

proyecto final de programacion 3, nov/2026-2

sistema multiusuario distribuido para apoyar la gestión de la emergencia.

registrar información y coordinar acciones sin depender de un único flujo secuencial de trabajo.
registrar y consultar personas afectadas, necesidades puntuales, recursos disponibles, albergues, reportes de mascotas perdidas o encontradas y mensajes destinados a facilitar la comunicación entre familiares.

## Arquitectura y Decisiones de Diseño

El sistema evita un flujo secuencial único mediante una arquitectura desacoplada en **cuatro capas** sobre la máquina virtual de Erlang (BEAM):

1. **Capa de Interfaz (`Emergencias.CLI` y `Emergencias.Util`):**
   * Bucle interactivo por consola con parseo seguro de argumentos (`OptionParser.split/1`), normalización de entradas y formateo de salidas.
2. **Capa de Coordinación y Seguridad (`Emergencias`):**
   * Fachada principal que verifica sesiones activas, aplica control de acceso por rol (`:ciudadano`, `:voluntario`, `:coordinador`, `:administrador`) y registra la bitácora de actividad antes de despachar peticiones.
3. **Capa de Concurrencia y Dominio (`Servers/*`, `Core/*`, `Modelos/*`):**
   * **7 procesos `GenServer` independientes:** `UsuariosServer`, `ZonasServer`, `NecesidadesServer`, `RecursosServer`, `PersonasServer`, `MascotasServer` y `AlberguesServer`.
   * **Exclusión mutua sin bloqueos manuales:** Las operaciones críticas (asignación de recursos escasos e ingreso a albergues) se serializan en el buzón FIFO de cada `GenServer`, evitando sobreasignaciones o cierres duplicados ante peticiones simultáneas[cite: 7, 17].
   * **Estructuras inmutables:** 8 `defstruct` tipados, mapas (`Map`) para búsquedas en $O(1)$ y `MapSet` en `%Albergue{}` para impedir registros duplicados de ocupantes.
   * **4 funciones recursivas propias** (implementadas con caso base y acumulador en `lib/emergencias/core/`):
     * `ZonasCore.calcular_afectados_zona/1`: Suma jerárquica recursiva **Zona → Sectores → Puntos de atención**.
     * `NecesidadesCore.filtrar_y_priorizar/2`: Filtrado multicriterio y ordenamiento por urgencia (`:critica` → `:alta` → `:media` → `:baja`).
     * `MascotasCore.buscar_coincidencias/2`: Emparejamiento (*matching*) entre mascotas perdidas y encontradas con puntaje de similitud sobre 100.
     * `AlberguesCore.reporte_mayor_ocupacion/1`: Construcción recursiva del ranking descendente de ocupación de albergues.
4. **Capa de Supervisión y Persistencia (`Emergencias.Application` y `Emergencias.Persistencia`):**
   * `Emergencias.Supervisor` supervisa los 7 trabajadores con estrategia `:one_for_one`, reiniciando automáticamente cualquier proceso ante un fallo y recargando su estado desde archivos de texto plano (`data/*.txt`).

---

## Estructura del Proyecto


Proyecto_final/
├── mix.exs                              # Configuración Mix y arranque OTP (Emergencias.Application)
├── README.md                            # Documentación técnica y guía de ejecución
├── data/                                # Persistencia en archivos de texto plano (.txt)
│   ├── usuarios.txt
│   ├── zonas.txt
│   ├── necesidades.txt
│   ├── recursos.txt
│   ├── personas.txt
│   ├── mensajes.txt
│   ├── mascotas.txt
│   └── albergues.txt
├── lib/
│   ├── emergencias.ex                   # Fachada principal y control de permisos por rol
│   └── emergencias/
│       ├── application.ex               # Supervisor raíz OTP (:one_for_one)
│       ├── cli.ex                       # Interfaz interactiva de consola
│       ├── persistencia.ex              # Lectura y escritura genérica en .txt
│       ├── util.ex                      # Funciones auxiliares de consola y validaciones base
│       ├── modelos/                     # 8 structs inmutables del dominio
│       ├── core/                        # 4 módulos puros con algoritmos recursivos
│       └── servers/                     # 7 servidores concurrentes GenServer
└── test/                                # Pruebas automatizadas con ExUnit
    ├── test_helper.exs
    ├── emergencias_test.exs             # Flujo integral, roles y recuperación OTP
    ├── recursividad_test.exs            # Pruebas de las 4 funciones recursivas
    └── concurrencia_test.exs            # Pruebas paralelas con Task.async


---

## Requisitos e Instrucciones de Ejecución

* **Elixir** `~> 1.14` y **Erlang/OTP** instalados.

### 1. Ejecutar pruebas automatizadas (`ExUnit`)
Verifica concurrencia (`Task.async`), recursividad, validaciones y recuperación ante fallos del Supervisor:

powershell
# Windows PowerShell
mix.bat test

# Linux / macOS / Git Bash
mix test


### 2. Iniciar la aplicación interactiva
Levanta el árbol de supervisión OTP e inicia la consola de comandos:

powershell
# Windows PowerShell
iex.bat -S mix

# Linux / macOS / Git Bash
iex -S mix


Dentro de la sesión `iex(1)>`:


# (Opcional) Verificar los 7 procesos supervisados activos:
Supervisor.which_children(Emergencias.Supervisor)

# Iniciar la interfaz de comandos:
Emergencias.CLI.iniciar()


---

## Flujo de Ejemplo en Consola (CLI)

# 1. Conexión como coordinadora y registro de zona
connect laura 1234 coordinador centro
register_zone Z01 Centro critico 120
check_zone Z01

# 2. Registro de necesidad crítica, inventario y asignación
register_need agua 30 critica centro "Punto atencion sector 3"
register_resource R001 agua 50 litros centro_acopio_1
assign_resource N001 agua 30
list_resources

# 3. Localización de personas, mensajes familiares y albergues
report_person 1094888 "Andres Gomez" centro localizada
send_family_message 1094888 "Estamos bien en el parque"
list_family_messages 1094888
register_shelter A01 "Albergue Norte" centro 50
register_entry A01 1094888
shelter_report

# 4. Reporte y emparejamiento (matching) de mascotas
report_pet lost perro "Luna" negra mediana centro 3105551111
report_pet found perro desconocido negra mediana centro 3205552222
match_pets
confirm_match MP001 ME002

# 5. Resumen global y cierre de sesión
summary
disconnect
exit
