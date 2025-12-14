#!/bin/bash
# Script de inicio rápido para el pipeline de transacciones con dbt

set -e

echo "=== Pipeline de Resumen de Transacciones ==="
echo ""

# Verificar si Docker está en ejecución
echo "Verificando estado de Docker..."
if ! docker info > /dev/null 2>&1; then
    echo ""
    echo "ERROR: ¡Docker no está en ejecución!"
    echo "Por favor inicia Docker Desktop (o el daemon de Docker) y espera a que esté completamente listo, luego ejecuta este script nuevamente."
    echo ""
    exit 1
fi
echo "¡Docker está en ejecución!"

# Detectar comando de Docker Compose (docker compose o docker-compose)
if docker compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
elif docker-compose version > /dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo "ERROR: No se encontró Docker Compose. Instala Docker Compose." >&2
    exit 1
fi

# Paso 1: Iniciar PostgreSQL
echo ""
echo "Paso 1: Iniciando contenedor PostgreSQL..."
$DOCKER_COMPOSE_CMD up -d

# Esperar a que PostgreSQL esté listo
echo "Esperando a que PostgreSQL esté listo..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker exec transactions_postgres pg_isready -U transactions_user -d transactions_db > /dev/null 2>&1; then
        echo "¡PostgreSQL está listo!"
        break
    fi
    attempt=$((attempt + 1))
    echo "  Intento $attempt/$max_attempts - esperando PostgreSQL..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "Error: PostgreSQL no se pudo iniciar después de $max_attempts intentos" >&2
    exit 1
fi

# Paso 2: Verificar que existe el perfil de dbt
echo ""
echo "Paso 2: Verificando perfil de dbt..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_YML_PATH="$SCRIPT_DIR/dbt_transactions/profiles.yml"
if [ ! -f "$PROFILES_YML_PATH" ]; then
    echo "ERROR: profiles.yml no encontrado en: $PROFILES_YML_PATH" >&2
    exit 1
fi
echo "Perfil de dbt encontrado en: $PROFILES_YML_PATH"

# Establecer variable de entorno DBT_PROFILES_DIR
export DBT_PROFILES_DIR="$SCRIPT_DIR/dbt_transactions"

# Detectar comando de Python (python3 en Mac/Ubuntu, python en Windows)
if command -v python3 > /dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python > /dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "ERROR: No se encontró Python. Instala Python 3.8 o superior." >&2
    exit 1
fi

# Paso 3: Convertir JSONL a archivo CSV seed
echo ""
echo "Paso 3: Convirtiendo JSONL a archivo CSV seed..."
$PYTHON_CMD load_transactions.py

# Paso 4: Cargar datos seed en PostgreSQL
echo ""
echo "Paso 4: Cargando datos seed en PostgreSQL..."
cd dbt_transactions
dbt seed --profiles-dir .
cd ..

# Paso 5: Ejecutar transformaciones dbt
echo ""
echo "Paso 5: Ejecutando transformaciones dbt..."
cd dbt_transactions
dbt run -s tag:business --profiles-dir .
cd ..

# Paso 6: Exportar a Parquet
echo ""
echo "Paso 6: Exportando a Parquet..."
$PYTHON_CMD export_to_parquet.py

echo ""
echo "=== Pipeline Completado ==="
echo "Resultados guardados en transactions_summary.parquet"
