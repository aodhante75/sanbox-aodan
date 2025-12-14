{{
    config(
        materialized='table',
        tags=['business']
    )
}}

-- Resumen agregado de transacciones aprobadas por BIN y fecha
select
    bin,
    transaction_date as day,
    count(*) as number_of_approved_transactions,
    sum(amount_cents) as total_approved_amount
from {{ ref('stg_transactions') }}
where status = 'APPROVED'
    and bin is not null
    and transaction_date is not null
    and amount_cents is not null
group by bin, transaction_date
order by bin, day
