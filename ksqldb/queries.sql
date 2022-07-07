create stream account_states_stream_keyed(PARTNER_ID VARCHAR KEY, IBAN VARCHAR,GUELTIG_AB VARCHAR, KONTOSTAND VARCHAR) with(kafka_topic='account_state_topic_schema', value_format='avro');
create stream account_state_stream as select partner_id, iban, parse_timestamp(gueltig_ab,'dd.MM.yyyy') as gueltig_ab, cast(kontostand as double) as kontostand from ACCOUNT_STATES_STREAM_KEYED emit changes;

select * from partner_profile emit changes;

select * from account_states_table where partner_id='1234';

select * from partner_profile emit changes;

select a.*, b.* from  account_states_table a join partner_profile b on a.partner_id=b.partner_id emit changes;

select * from account_summary where partner_id='1234';

select a.*, b.* from  account_summary a join partner_profile b on a.partner_id=b.partner_id emit changes;

select * from partner where a_partner_id='1234';
