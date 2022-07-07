create stream account_states_stream_keyed(PARTNER_ID VARCHAR KEY, IBAN VARCHAR,GUELTIG_AB VARCHAR, KONTOSTAND VARCHAR) with(kafka_topic='account_state_topic_schema', value_format='avro');

create stream account_states_stream as select REGEXP_EXTRACT('^(.*)=(.*)}$', partner_id,2) as PARTNER_ID, iban, parse_timestamp(gueltig_ab,'dd.MM.yyyy') as gueltig_ab, cast(kontostand as double) as kontostand from ACCOUNT_STATES_STREAM_KEYED partition by REGEXP_EXTRACT('^(.*)=(.*)}$', partner_id,2)  emit changes;

create table partner_profile(PARTNER_ID string primary key,PARTNER_NAME string, ADRESSE ARRAY<STRUCT<ADRESSE_TYP string, ADRESSE_STRASSE string, ADRESSE_PLZ string, ADRESSE_ORT string>> ) with (kafka_topic='partner_profile_topic', format='avro');

create table queryable_partner_profile as select * from partner_profile emit changes;

create table account_states_table with (key_format='AVRO') as select partner_id, iban, LATEST_BY_OFFSET(GUELTIG_AB) as gueltig_ab, LATEST_BY_OFFSET(kontostand) as kontostand from account_states_stream group by partner_id, iban emit changes;

create table account_summary as select partner_id, sum(kontostand), collect_list(iban) as ibans  from account_states_table group by partner_id emit changes;

create table partner as select a.*, b.* from  account_summary a join partner_profile b on a.partner_id=b.partner_id emit changes;

create or replace table PARTNER_FLATTENED as select A_PARTNER_ID as PARTNER_ID, A_KSQL_COL_0 as ACCOUNT_SUM, ARRAY_JOIN(A_IBANS) as IBANS, B_PARTNER_NAME as PARTNER_NAME FROM PARTNER emit changes;
