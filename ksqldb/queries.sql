create stream account_states_stream_keyed(PARTNER_ID VARCHAR KEY, IBAN VARCHAR,GUELTIG_AB VARCHAR, KONTOSTAND VARCHAR) with(kafka_topic='account_state_topic_schema', value_format='avro');
create stream account_state_stream as select partner_id, iban, parse_timestamp(gueltig_ab,'dd.MM.yyyy') as gueltig_ab, cast(kontostand as double) as kontostand from ACCOUNT_STATES_STREAM_KEYED emit changes;
