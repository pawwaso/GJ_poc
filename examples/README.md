##
- connector_SpoolDir_accounts_struct.json - contains alternative way to configure ingress 'spoolDir' connector makes use of predefined schemas suing kafka.connect model
- Account_struct.json - contains STRUCT definition of account_state (used for alternative definition of connector's configuration)
- AccountKey.json -  connector may accept STRUCT definition of KEY part too
- 1_partner_key.json -  is a sample value of partner_id KEY used with kafka-console-avro-producer 
- 1_partner.json - is a sample value of partner-profile used with kafka-console-avro-producer
- konten_init.csv - contains sample for initial load for a connector
