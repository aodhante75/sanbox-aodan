#!/usr/bin/env python3
"""Exporta la tabla transactions_summary de PostgreSQL a formato Parquet."""

import sys
from pathlib import Path
import psycopg2
import pandas as pd


def export_to_parquet(output_file: str = "transactions_summary.parquet"):
    """Exporta la tabla transactions_summary a formato Parquet."""
    try:
        print("Conectando a PostgreSQL...")
        with psycopg2.connect(
            host="localhost",
            port=5433,
            user="transactions_user",
            password="transactions_pass",
            database="transactions_db"
        ) as conn:
            print("Leyendo tabla transactions_summary...")
            df = pd.read_sql_query(
                "SELECT * FROM transactions_summary ORDER BY bin, day",
                conn
            )
        
        print(f"Escribiendo a {output_file}...")
        Path(output_file).parent.mkdir(parents=True, exist_ok=True)
        df.to_parquet(output_file, engine="pyarrow", compression="snappy", index=False)
        
        print(f"\n¡Éxito! Exportadas {len(df)} filas a {output_file}")
        print(f"  Total de transacciones aprobadas: {df['number_of_approved_transactions'].sum()}")
        print(f"  Monto total aprobado (centavos): {df['total_approved_amount'].sum():,}")
        
    except psycopg2.OperationalError as e:
        print(f"Error al conectar a PostgreSQL: {e}", file=sys.stderr)
        print("Asegúrate de que PostgreSQL esté en ejecución: docker-compose up -d", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    export_to_parquet(sys.argv[1] if len(sys.argv) > 1 else "transactions_summary.parquet")
