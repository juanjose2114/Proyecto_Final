defmodule Emergencias.Persistencia do
  @moduledoc """
  Módulo reutilizable para guardar y cargar el estado de cada dominio
  en archivos de texto plano (.txt) dentro de la carpeta /data.
  """

  @carpeta_datos "data"

  @doc """
  Guarda cualquier estructura de datos (Map, Struct, List, MapSet) en texto plano
  legible dentro de data/<nombre_archivo>.
  """
  def guardar(nombre_archivo, datos) when is_binary(nombre_archivo) do
    File.mkdir_p!(@carpeta_datos)
    ruta = Path.join(@carpeta_datos, nombre_archivo)
    contenido_texto = inspect(datos, pretty: true, limit: :infinity)

    case File.write(ruta, contenido_texto) do
      :ok -> :ok
      {:error, razon} -> {:error, "No se pudo guardar #{nombre_archivo}: #{razon}"}
    end
  end

  @doc """
  Carga los datos desde data/<nombre_archivo>.
  Si el archivo aún no existe (:enoent), retorna el valor por defecto sin fallar.
  """
  def cargar(nombre_archivo, valor_por_defecto \\ %{}) when is_binary(nombre_archivo) do
    ruta = Path.join(@carpeta_datos, nombre_archivo)

    case File.read(ruta) do
      {:ok, contenido} ->
        parsear_contenido(String.trim(contenido), valor_por_defecto)

      {:error, :enoent} ->
        {:ok, valor_por_defecto}

      {:error, razon} ->
        {:error, "Error leyendo #{nombre_archivo}: #{razon}"}
    end
  end

  defp parsear_contenido("", valor_por_defecto), do: {:ok, valor_por_defecto}

  defp parsear_contenido(contenido, _valor_por_defecto) do
    try do
      {datos, _bindings} = Code.eval_string(contenido)
      {:ok, datos}
    rescue
      _ -> {:error, :archivo_corrupto}
    end
  end
end
