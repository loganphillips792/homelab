
`cd docker`
`docker compose up --build `
`docker compose -f docker/docker-compose.yml up -d --force-recreate pihole`
`docker compose up --build jellyfin`

# Services

## Kafka

Create Topics

Topic that orchestrator pushes to:
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create \
  --topic scan.commands \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```

Topic that workers push to, and orchestrator reads from
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --create \
  --topic scan.events \
  --bootstrap-server localhost:9092 \
  --partitions 3 \
  --replication-factor 1
```


List Topics
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --list \
  --bootstrap-server localhost:9092
```


Describe Topic
```
docker exec kafka /opt/kafka/bin/kafka-topics.sh --describe \
  --topic scan.commands \
  --bootstrap-server localhost:9092
```


Send Message (producer)
```
docker exec -it kafka /opt/kafka/bin/kafka-console-producer.sh \
  --topic scan.commands \
  --bootstrap-server localhost:9092
```


Consume Messages (consumer)
```
docker exec -it kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --topic scan.commands \
  --bootstrap-server localhost:9092 \
  --from-beginning
```


Check consumer groups
```
docker exec kafka /opt/kafka/bin/kafka-consumer-groups.sh --list \
  --bootstrap-server localhost:9092
```

## Kafka UI

localhost:8080

## Grafana

localhost:3000


## N8N

localhost:5678


## Dozzle

localhost:8083

## PiHole

http://localhost/admin/



- Create a single volumes directory to make it easy to back up all data ??


## Homepage

## Uptime Kuma

not natively. Uptime Kuma doesn’t read a static config file on start; it stores monitors
in a SQLite DB under /app/data. You will have to manually import the backup file.

## Tailscale

1. Create account at https://login.tailscale.com/admin
2. Generate auth key and add to env variable
3. `docker compose up --build tailscale`
4. Go to `https://login.tailscale.com/admin/machines` and you should see the machine


## Test Postgres



if you have to rerun the SQL script: `docker compose -f docker/docker-compose.yml exec -T test-db psql -U testuser -d test_database -f docker-entrypoint-initdb.d/10-test-table.sql`


`docker exec -it postgres_db psql -U testuser -d test_database -c 'SELECT * FROM "test-table";'`










TRY GPT 5 API WIT THIS

Yes, the modern recommended stack for observability in 2025 consists of **Grafana**, **Prometheus**, **Loki**, and **Alloy**.[1][2][3]

## Stack Overview
- **Grafana**: Visualization and dashboard tool, connects to Prometheus and Loki for querying metrics and logs.
- **Prometheus**: Metrics collection and storage system, primarily used for monitoring and alerting.
- **Loki**: Log aggregation system, designed for storing and querying log data efficiently.
- **Alloy**: Observability collector that now serves as the unified agent for collecting and sending both metrics (to Prometheus) and logs (to Loki); it replaces older agents like Promtail and the Grafana Agent, which hit end-of-life in 2025.[2][3]

## Recommended Architecture
- Alloy acts as the collector and shipper, scraping data from hosts, containers, or cloud services.
- Logs are sent from Alloy to Loki, and metrics to Prometheus.
- Grafana connects to both Loki and Prometheus to provide a unified analytics and visualization experience.[4][3][1]

This stack is considered state-of-the-art, scalable, and feature-rich for both infrastructure and application observability as as of 2025.[10][1][2]

[1](https://grafana.com/docs/alloy/latest/tutorials/send-logs-to-loki/)
[2](https://grafana.com/docs/loki/latest/setup/migrate/migrate-to-alloy/)
[3](https://grafana.com/docs/loki/latest/send-data/alloy/)
[4](https://freshbrewed.science/2025/07/15/alloyotlp.html)
[5](https://grafana.com/docs/loki/latest/get-started/overview/)
[6](https://grafana.com/docs/alloy/latest/tutorials/send-metrics-to-prometheus/)
[7](https://grafana.com/docs/loki/latest/get-started/)
[8](https://grafana.com/docs/loki/latest/operations/meta-monitoring/)
[9](https://www.reddit.com/r/grafana/comments/1ktigw4/which_log_shipper_do_you_use_for_loki_in_2025/)
[10](https://grafana.com/docs/alloy/latest/set-up/install/)