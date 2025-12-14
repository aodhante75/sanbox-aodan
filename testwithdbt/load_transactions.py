"""Convierte archivo JSONL a CSV para usar como seed en dbt."""
import csv
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
input_file = os.path.join(script_dir, "transactions_50k.jsonl")
output_file = os.path.join(script_dir, "dbt_transactions", "seeds", "raw_transactions.csv")

os.makedirs(os.path.dirname(output_file), exist_ok=True)

count = 0
with open(input_file, "r", encoding="utf-8") as infile, \
     open(output_file, "w", newline="", encoding="utf-8") as outfile:
    writer = csv.DictWriter(outfile, fieldnames=["transaction"])
    writer.writeheader()
    for line in infile:
        writer.writerow({"transaction": line.strip()})
        count += 1

print(f"CSV generado: {count} registros")
