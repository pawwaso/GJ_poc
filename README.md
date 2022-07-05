
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
#### start containers
1. cd <mainDir>
2. docker-compose up -d
#### deploy ingress connector   
3. curl -d @kafka-connect-connectors/connector_SAP_ftp_accounts_config.json -X  POST -H "Content-Type: application/json" -H "Accept: application/json" http://<ADVERTISED_HOST>:8083/connectors
#### bash into ksqldb-cli
4. docker-compose exec ksqldb-cli bash
5. ksql http://ksqldb-server:8088
#### setting offset to earliest forces queries to process all messages   
6. SET 'auto.offset.reset' = 'earliest';
#### stream abstraction over existing topic, no query yet   
7. create stream account_states_stream_keyed(PARTNER_ID VARCHAR KEY, IBAN VARCHAR,GUELTIG_AB VARCHAR, KONTOSTAND VARCHAR) with(kafka_topic='account_state_topic_schema', value_format='avro');
#### CSAS syntax- new stream and new query taht runs in the background
8. create stream account_state_stream as select partner_id, iban, parse_timestamp(gueltig_ab,'dd.MM.yyyy') as gueltig_ab, cast(kontostand as double) as kontostand from ACCOUNT_STATES_STREAM_KEYED emit changes;
9. exit #ksql cli
10. exit # docker container
#### create and post schemas (key and value) from respective files   located in schemas/partner_{profile|key}.avro 
11. curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" -d @schemas/partner_profile.avro http://<ADVERTISED_HOST>:8081/subjects/partner_profile_topic-value/versions
12. curl -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" -d @schemas/partner_key.avro http://<ADVERTISED_HOST>:8081/subjects/partner_profile_topic-key/versions  
#### know your ids (in the response there will be 'id' field; note the values)    
13. curl -X GET http://<ADVERTISED_HOST>:8081/subjects/partner_profile_topic-value/versions/latest # grab '<id>'
14. curl -X GET http://<ADVERTISED_HOST>:8081/subjects/partner_profile_topic-key/versions/latest # grab '<id>'   
#### create topic partner_profile  , cleanup.oolicy set to compact, lets us create table abstraction over it, message key may be set (as below) then table may just use it, or not, in which case table definition would need to specify message field as key; both key and value get validated  
15. docker-compose exec broker bash
16. kafka-topics --create --bootstrap-server broker:9092 --replication-factor 1 --partitions 1 --topic partner_profile_topic --config cleanup.policy=compact --config confluent.value.schema.validation=true --config confluent.key.schema.validation=true
#### kafka-console-avro tools are available in schema-registry container    
17. docker-compose exec schema-registry bash
#### messages with specified schemas may be produced. below, the key.separator is set to '---'
18. kafka-avro-console-producer --broker-list broker:9092  --topic partner_profile_topic --property schema.registry.url=http://schema-registry:8081 --property value.schema.id=4 --property key.schema.id=5 --property parse.key=true --property key.separator="---"
#### in order to produce a message with it, write e.g.
#### `"1234"---{"partner_id": "1234", "partner_name": "some partner name", "adresse": {"array":[{"adresse_typ": "10", "adresse_strasse": "bvncykluhewxxlk", "adresse_plz": "ardepwgihgd", "adresse_ort": "kmeneeioeyhmvxumkjdpkkfd" }, {"adresse_typ": "20", "adresse_strasse": "ekdotopsqikglrquiuqydpkl", "adresse_plz": "", "adresse_ort": "pecqgljrde"}, {"adresse_typ": "30", "adresse_strasse": "tuidcti", "adresse_plz": "kbgpauittmsvpmomiyjnywjm", "adresse_ort": "x"}]}}`
#### in one line (both sample key and value are available in examples/ folder)
19. EXIT | docker-compose exec ksqldb-server bash
#### and create a table abstraction over this topic     
20. ksql http://ksqldb-server:8088
#### field names shall be upper-cased in taht case, and the structure `ARRAY<STRUCT<...>>` corresponds to avro schema defined    
21. create table partner_profile(PARTNER_ID string primary key,PARTNER_NAME string, ADRESSE ARRAY<STRUCT<ADRESSE_TYP string, ADRESSE_STRASSE string, ADRESSE_PLZ string, ADRESSE_ORT string>> ) with (kafka_topic='partner_profile_topic', format='avro');
#### with push query messages may be queried from this topic    
22. select * from partner_profile emit changes;
#### but in order to query this topic using pull queries/ where clauses  a table backed by running query is needed  
23. create table queryable_partner_profile as select * from partner_profile emit changes;
23. exit
#### now it is possible to use http RPC call to query for specific key      
24. curl -X "POST" --http2 "http://192.168.64.11:8088/query-stream"      -d $'{
    "sql": "SELECT * FROM QUERYABLE_PARTNER_PROFILE WHERE PARTNER_ID=\'${partnerId}\';",             
    "streamsProperties": {},
    "sessionVariables":{"partnerId":"1234"}}'
#### or issue a continuous query    
25.  curl -X "POST" --http2 "http://<ADVERTISED_HOST>:8088/query-stream"      -d $'{
     "sql": "SELECT * FROM QUERYABLE_PARTNER_PROFILE WHERE PARTNER_ID=\'${partnerId}\' emit changes;",             
     "streamsProperties": {},
     "sessionVariables":{"partnerId":"1234"}}'
#### yet another way with 'query' endpoint (no need for http2)     
26. curl -X "POST" "http://<ADVERTISED_HOST>:8088/query"  -H "ACCEPT: application/vnd.ksql.v1+json"    -d $'{
    "ksql": "SELECT * FROM QUERYABLE_PARTNER_PROFILE WHERE PARTNER_ID=\'1234\' ;",
    "streamsProperties": {"ksql.streams.auto.offset.reset": "earliest"}}'
