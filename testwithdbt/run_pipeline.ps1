# Script de inicio rápido para el pipeline de transacciones con dbt (PowerShell)

Write-Host "=== Pipeline de Resumen de Transacciones ===" -ForegroundColor Cyan
Write-Host ""

# Verificar si Docker está en ejecución
Write-Host "Verificando estado de Docker..." -ForegroundColor Yellow
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker no está en ejecución"
    }
    Write-Host "¡Docker está en ejecución!" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "ERROR: ¡Docker Desktop no está en ejecución!" -ForegroundColor Red
    Write-Host "Por favor inicia Docker Desktop y espera a que esté completamente listo, luego ejecuta este script nuevamente." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Paso 1: Iniciar PostgreSQL
Write-Host ""
Write-Host "Paso 1: Iniciando contenedor PostgreSQL..." -ForegroundColor Yellow
docker-compose up -d

# Esperar a que PostgreSQL esté listo
Write-Host "Esperando a que PostgreSQL esté listo..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$ready = $false

while ($attempt -lt $maxAttempts) {
    $result = docker exec transactions_postgres pg_isready -U transactions_user -d transactions_db 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "¡PostgreSQL está listo!" -ForegroundColor Green
        $ready = $true
        break
    }
    $attempt++
    Write-Host "  Intento $attempt/$maxAttempts - esperando PostgreSQL..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}

if (-not $ready) {
    Write-Host "Error: PostgreSQL no se pudo iniciar después de $maxAttempts intentos" -ForegroundColor Red
    exit 1
}

# Paso 2: Verificar que existe el perfil de dbt
Write-Host ""
Write-Host "Paso 2: Verificando perfil de dbt..." -ForegroundColor Yellow
$dbtProjectPath = Join-Path $PSScriptRoot "dbt_transactions"
$profilesYmlPath = Join-Path $dbtProjectPath "profiles.yml"
if (-not (Test-Path $profilesYmlPath)) {
    Write-Host "ERROR: profiles.yml no encontrado en: $profilesYmlPath" -ForegroundColor Red
    exit 1
}
Write-Host "Perfil de dbt encontrado en: $profilesYmlPath" -ForegroundColor Green

# Establecer variable de entorno DBT_PROFILES_DIR para esta sesión
$env:DBT_PROFILES_DIR = $dbtProjectPath

# Paso 3: Convertir JSONL a archivo CSV seed
Write-Host ""
Write-Host "Paso 3: Convirtiendo JSONL a archivo CSV seed..." -ForegroundColor Yellow
python load_transactions.py

# Paso 4: Cargar datos seed en PostgreSQL
Write-Host ""
Write-Host "Paso 4: Cargando datos seed en PostgreSQL..." -ForegroundColor Yellow
Set-Location dbt_transactions
dbt seed --profiles-dir .
Set-Location ..

# Paso 5: Ejecutar transformaciones dbt
Write-Host ""
Write-Host "Paso 5: Ejecutando transformaciones dbt..." -ForegroundColor Yellow
Set-Location dbt_transactions
dbt run -s tag:business --profiles-dir .
Set-Location ..

# Paso 6: Exportar a Parquet
Write-Host ""
Write-Host "Paso 6: Exportando a Parquet..." -ForegroundColor Yellow
python export_to_parquet.py

Write-Host ""
Write-Host "=== Pipeline Completado ===" -ForegroundColor Green
Write-Host "Resultados guardados en transactions_summary.parquet" -ForegroundColor Green
