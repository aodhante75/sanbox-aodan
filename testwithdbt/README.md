# Resumen de Transacciones con dbt y PostgreSQL

Proyecto que procesa transacciones de tarjetas de crédito usando dbt para transformaciones y PostgreSQL como base de datos. Los datos se cargan desde un archivo JSONL, se transforman con modelos dbt y se genera un resumen agregado agrupado por BIN (Bank Identification Number) y fecha.

## Arquitectura

- **PostgreSQL**: Base de datos en contenedor Docker
- **dbt**: Herramienta de transformación de datos
- **Python**: Script para cargar datos JSONL a PostgreSQL

## Estructura del Proyecto

```
testwithdbt/
├── docker-compose.yml          # Configuración PostgreSQL
├── load_transactions.py        # Convierte JSONL a CSV
├── export_to_parquet.py        # Exporta resumen a Parquet
├── run_pipeline.ps1            # Script automatizado (PowerShell)
├── run_pipeline.sh             # Script automatizado (Bash)
├── transactions_50k.jsonl      # Archivo de datos JSONL (debe estar en esta carpeta)
└── dbt_transactions/           # Proyecto dbt
    ├── dbt_project.yml
    ├── profiles.yml
    └── models/
        ├── staging/
        │   └── stg_transactions.sql    # Parsea JSON y extrae campos
        └── marts/
            └── transactions_summary.sql # Resumen agregado final
```

## Requisitos

- Docker y Docker Compose
- Python 3.8+
- dbt CLI

### Consideraciones para Mac y Ubuntu

**Python:**
- El script `run_pipeline.sh` detecta automáticamente si usar `python` o `python3`
- En Mac/Ubuntu, generalmente se usa `python3`
- Verifica con: `python3 --version`

**Permisos de ejecución:**
- El script `run_pipeline.sh` necesita permisos de ejecución:
  ```bash
  chmod +x run_pipeline.sh
  ```

**Docker:**
- En Ubuntu, puede ser necesario agregar tu usuario al grupo `docker`:
  ```bash
  sudo usermod -aG docker $USER
  # Luego cierra sesión y vuelve a iniciar sesión
  ```
- En Mac, Docker Desktop maneja los permisos automáticamente
- Verifica que Docker esté en ejecución: `docker info`

**Docker Compose:**
- El script `run_pipeline.sh` detecta automáticamente si usar `docker compose` o `docker-compose`
- En versiones recientes de Docker, el comando es `docker compose` (sin guión)
- Si ejecutas manualmente y `docker-compose` no funciona, prueba: `docker compose up -d`

**Puerto 5433:**
- Verifica que el puerto 5433 esté disponible:
  ```bash
  # Mac/Ubuntu
  lsof -i :5433
  # Si está en uso, cambia el puerto en docker-compose.yml
  ```

**dbt CLI:**
- Instalación recomendada con pip:
  ```bash
  pip3 install dbt-postgres
  ```
- O con Homebrew (Mac):
  ```bash
  brew install dbt-postgres
  ```

## Instalación

1. **Instalar dependencias Python:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Iniciar PostgreSQL:**
   ```bash
   docker-compose up -d
   ```

   Configuración:
   - Host: `localhost`
   - Puerto: `5432`
   - Base de datos: `transactions_db`
   - Usuario: `transactions_user`
   - Contraseña: `transactions_pass`

## Inicio Rápido

**Importante:** Asegúrate de que el archivo `transactions_50k.jsonl` esté en la carpeta raíz del proyecto (`testwithdbt/`) antes de ejecutar el pipeline.

Ejecuta el pipeline completo automáticamente:

**Windows:**
```bash
.\run_pipeline.ps1
```

**Linux/Mac:**
```bash
chmod +x run_pipeline.sh
./run_pipeline.sh
```

**Nota para Mac/Ubuntu:** El script `run_pipeline.sh` detecta automáticamente si usar `python` o `python3`.

El script:
1. Inicia PostgreSQL
2. Convierte JSONL a CSV
3. Carga datos con dbt seed
4. Ejecuta transformaciones dbt
5. Exporta resultados a Parquet

## Uso Manual

### Paso 1: Convertir JSONL a CSV

**Nota:** El archivo `transactions_50k.jsonl` debe estar en la carpeta raíz del proyecto (`testwithdbt/`).

```bash
# Mac/Ubuntu: usar python3 si python no está disponible
python3 load_transactions.py
# O
python load_transactions.py
```

Convierte `transactions_50k.jsonl` a CSV con columna `transaction` (JSON como texto).

### Paso 2: Cargar datos y ejecutar transformaciones

```bash
cd dbt_transactions
dbt seed --profiles-dir .
dbt run --profiles-dir .
```

### Paso 3: Exportar a Parquet (opcional)

```bash
# Mac/Ubuntu: usar python3 si python no está disponible
python3 export_to_parquet.py
# O
python export_to_parquet.py
```

## Esquema de Salida

La tabla `transactions_summary` contiene:

| Columna | Tipo | Descripción |
|---------|------|-------------|
| `bin` | VARCHAR | Número de identificación bancaria |
| `day` | DATE | Fecha de transacción |
| `number_of_approved_transactions` | BIGINT | Cantidad de transacciones aprobadas |
| `total_approved_amount` | BIGINT | Suma de montos aprobados (en centavos) |

## Modelos dbt

### `stg_transactions` (Staging)

- **Materialización**: Tabla
- **Fuente**: `raw_transactions` (seed con columna `transaction` como texto)
- **Transformaciones**:
  - Convierte texto JSON a JSONB usando `::jsonb`
  - Extrae campos usando operadores JSONB (`->`, `->>`)
  - Convierte tipos de datos (strings a integers, booleans, timestamps)

### `transactions_summary` (Marts)

- **Materialización**: Tabla
- **Propósito**: Resumen agregado final
- **Agregaciones**:
  - Filtra solo transacciones aprobadas
  - Agrupa por BIN y fecha
  - Cuenta transacciones y suma montos

## Consultar Resultados

**Desde PostgreSQL:**
```bash
docker exec -it transactions_postgres psql -U transactions_user -d transactions_db
SELECT * FROM transactions_summary LIMIT 10;
```

**Con dbt:**
```bash
cd dbt_transactions
dbt show --select transactions_summary --limit 10
```

## Comandos dbt Útiles

```bash
cd dbt_transactions

# Ejecutar todos los modelos
dbt run --profiles-dir .

# Ejecutar modelo específico
dbt run --select transactions_summary --profiles-dir .

# Compilar SQL
dbt compile --profiles-dir .

# Generar documentación
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

## Solución de Problemas

### Python no encontrado (Mac/Ubuntu)

Si obtienes `python: command not found`, usa `python3`:
```bash
python3 load_transactions.py
python3 export_to_parquet.py
```

O crea un alias permanente en `~/.bashrc` o `~/.zshrc`:
```bash
alias python=python3
```

### Docker requiere sudo (Ubuntu)

Si Docker requiere `sudo`, agrega tu usuario al grupo docker:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Puerto 5433 en uso

Si el puerto 5433 está ocupado, edita `docker-compose.yml` y cambia:
```yaml
ports:
  - "5434:5432"  # Cambia 5433 a otro puerto disponible
```

Luego actualiza `profiles.yml` y `export_to_parquet.py` con el nuevo puerto.

### PostgreSQL no inicia

```bash
docker-compose ps
docker-compose logs postgres
docker-compose restart postgres
```

### Error de conexión dbt

Verifica que `profiles.yml` esté en `dbt_transactions/` o usa:
```bash
dbt run --profiles-dir .
```

### Error al parsear JSON

Verifica que el CSV tenga la columna `transaction` con JSON válido. Prueba en PostgreSQL:
```sql
SELECT transaction::jsonb->>'id' FROM raw_transactions LIMIT 1;
```

## Limpieza

Detener contenedor:
```bash
docker-compose down
```

Eliminar contenedor y datos:
```bash
docker-compose down -v
```

## Ventajas de JSONB en PostgreSQL

- **Almacenamiento eficiente**: JSON binario con indexación automática
- **Consultas flexibles**: Operadores JSON (`->`, `->>`, `@>`)
- **Sin pérdida de datos**: Estructura JSON completa preservada
