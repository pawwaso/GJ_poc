
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


# Run
start with `docker-compose  --env-file ./config/.k8s up -d` for e.g., minikube based docker (set ADVERTISED_HOST to `minikube ip`) or
with `docker-compose  --env-file ./config/.localhost up -d` for native docker installation
