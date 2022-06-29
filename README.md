
# Confluent based Kafka ecosystem
For internal PoC.
The goal of this PoC is to
1. ingest data using SPOOL dir connector
2. accept properly formatted messages from simulated producer
3. apply ksqlDB stream processing
4. sink topics into mssql
5. provide platfrom for key based pull queries. Via REST exposed in ksqlDB.

Project leverages newest version of confluent server. However, as broker side schema validation is supposed to be demostrated within this PoC, and it requires `confluent-server`image (`ver 7.1.1`), this setup does not make use of KRaft, hence zookeeper is stil deployed.

# Documentation
## Content
- [./configs/.localhost env prooperties](./configs/.localhost) contain ADVERTISED_HOST. Used in as docker-compose `env-file`  
- [create DB script](./db/scripts/createDB.sql) creates MSQL DB at startup. Called in docker-compose
- [docker-compose.yaml](./docker-compose.yaml) starts all contaiiners (zoookeeper, broker, connect, ksqldb, coontrol-center, mssql)
- [kafka-connect](./kafka-connect) contains additional connectors to be deployed at startup [spoolDir Source connector](./kafka-connect/jcustenborder-kafka-connect-spooldir-2.0.64) and [jdbc Sink connector](./kafka-connect/confluentinc-kafka-connect-jdbc-10.5.0)
- [kafka-connect-input-dir](./kafka-connect-input-dir) is volume mapped to internal input folder


# Run instructions

## Command
start with `docker-compose  --env-file ./config/.k8s up -d` for e.g., minikube based docker (set ADVERTISED_HOST to `minikube ip`) or
with `docker-compose  --env-file ./config/.localhost up -d` for native docker installation.

After startup few conatiners shall be running. In case `schema-registry` and/or `control-center` did not start just run `docker-compose...` command again.

## Init state

If successful, few containers shall run including (`conenct`,`ksqldb`, `mssql`). `mssql` is MS SQL Server with `GJ_TEST` DB created.


## Sequence

1. cd <mainDir>
2. docker-compose up -d
3. curl -d @kafka-connect-connectors/connector_SAP_ftp_accounts_config.json -X  POST -H "Content-Type: application/json" -H "Accept: application/json" http://<ADVERTISED_HOST>:8083/connectors
4. docker-compose exec ksqldb-cli bash
5. ksql http://ksqldb-server:8088
6. SET 'auto.offset.reset' = 'earliest';
7. create stream account_states_stream_keyed(PARTNER_ID VARCHAR KEY, IBAN VARCHAR,GUELTIG_AB VARCHAR, KONTOSTAND VARCHAR) with(kafka_topic='account_state_topic_schema', value_format='avro');
8. create stream account_state_stream as select partner_id, iban, parse_timestamp(gueltig_ab,'dd.MM.yyyy') as gueltig_ab, cast(kontostand as double) as kontostand from ACCOUNT_STATES_STREAM_KEYED emit changes;
