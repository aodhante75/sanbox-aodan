{{
    config(
        materialized='view',
        tags=['business']
    )
}}

-- Parsea JSON y extrae campos de transacciones
select
    (transaction::jsonb)->>'id' as id,
    (transaction::jsonb)->>'created_at' as created_at,
    (transaction::jsonb)->>'updated_at' as updated_at,
    (transaction::jsonb)->>'status' as status,
    (transaction::jsonb)->'payment_method_type'->>'type' as payment_method_type,
    ((transaction::jsonb)->'payment_method_type'->>'installments')::integer as installments,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'bin' as bin,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'card_holder' as card_holder,
    ((transaction::jsonb)->'payment_method_type'->'extra'->>'is_three_ds')::boolean as is_three_ds,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'unique_code' as unique_code,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'three_ds_auth_type' as three_ds_auth_type,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'external_identifier' as external_identifier,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'processor_response_code' as processor_response_code,
    (transaction::jsonb)->'payment_method_type'->'extra'->>'authorizer_transaction_id' as authorizer_transaction_id,
    date(((transaction::jsonb)->>'created_at')::timestamp) as transaction_date,
    ((transaction::jsonb)->>'amount_in_cents')::bigint as amount_cents
from {{ ref('raw_transactions') }}
