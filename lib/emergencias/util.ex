defmodule Emergencias.Util do
  @moduledoc """
  Utilidades de entrada/salida por consola, normalización de cadenas,
  generación de IDs y validaciones básicas con guards.
  """

  # --- Entrada y salida por consola (patrón de clase) ---

  def mostrar_mensaje(mensaje), do: IO.puts(mensaje)

  def mostrar_error(mensaje), do: IO.puts(:stderr, "[ERROR] #{mensaje}")

  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> to_string()
    |> String.trim()
  end

  def ingresar(mensaje, :entero), do: ingresar(mensaje, &String.to_integer/1, :entero)
  def ingresar(mensaje, :real), do: ingresar(mensaje, &String.to_float/1, :real)

  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        mostrar_error("Se esperaba un valor de tipo #{tipo_dato}. Intente nuevamente.")
        ingresar(mensaje, parser, tipo_dato)
    end
  end

  # --- Funciones puras de apoyo ---

  def normalizar(texto) when is_binary(texto) do
    texto
    |> String.trim()
    |> String.downcase()
  end

  def validar_no_vacio(texto, campo) when is_binary(texto) do
    limpio = String.trim(texto)
    if limpio == "", do: {:error, "El campo '#{campo}' no puede estar vacío"}, else: {:ok, limpio}
  end

  def validar_no_vacio(_, campo), do: {:error, "El campo '#{campo}' debe ser texto"}

  def validar_positivo(cantidad) when is_number(cantidad) and cantidad > 0, do: {:ok, cantidad}
  def validar_positivo(_), do: {:error, :cantidad_debe_ser_positiva}

  def validar_no_negativo(cantidad) when is_integer(cantidad) and cantidad >= 0, do: {:ok, cantidad}
  def validar_no_negativo(_), do: {:error, :cantidad_no_puede_ser_negativa}

  def fecha_actual do
    NaiveDateTime.utc_now()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  def generar_id(prefijo) when is_binary(prefijo) do
    numero = :erlang.unique_integer([:positive, :monotonic])
    "#{String.upcase(prefijo)}-#{numero}"
  end
end
