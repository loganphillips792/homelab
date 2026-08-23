#!/usr/bin/env python3
"""Kafka consumer for the homelab testing stack.

Subscribes to a topic, logs every message, and commits offsets explicitly so the
group's lag shows up in kafka-ui (kafka-ui.homelab -> Consumer Groups) and akhq.

Configured entirely by environment variable; the values live in
../docker-compose.yml so you can retarget the consumer without touching code.
"""
import json
import logging
import os
import signal
import sys

from confluent_kafka import Consumer, KafkaError, KafkaException
from confluent_kafka.admin import AdminClient, NewTopic

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "kafka:29092")
TOPIC = os.environ.get("KAFKA_TOPIC", "scan.commands")
GROUP = os.environ.get("KAFKA_GROUP", "scan-workers")
OFFSET_RESET = os.environ.get("KAFKA_AUTO_OFFSET_RESET", "earliest")
PARTITIONS = int(os.environ.get("KAFKA_TOPIC_PARTITIONS", "3"))

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-5s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    stream=sys.stdout,
)
log = logging.getLogger("consumer")

running = True


def _shutdown(signum, _frame):
    # Docker sends SIGTERM on `compose down`/`stop`. Dropping out of the poll loop
    # lets the consumer leave the group cleanly instead of the group stalling until
    # session.timeout.ms expires.
    global running
    log.info("received %s, shutting down", signal.Signals(signum).name)
    running = False


def ensure_topic():
    """Create the topic if it is missing, with the right partition count.

    The broker runs with KAFKA_AUTO_CREATE_TOPICS_ENABLE=true, so subscribing to a
    missing topic would create it with a single partition — and the README's
    `--partitions 3` create command would then fail with TopicExistsException.
    Creating it explicitly means startup order stops mattering.
    """
    admin = AdminClient({"bootstrap.servers": BOOTSTRAP})
    if TOPIC in admin.list_topics(timeout=10).topics:
        return
    log.info("topic %r missing, creating it with %d partitions", TOPIC, PARTITIONS)
    for topic, fut in admin.create_topics([NewTopic(TOPIC, PARTITIONS, 1)]).items():
        try:
            fut.result()
            log.info("created topic %r", topic)
        except KafkaException as exc:
            # Another consumer instance may have won the race; that is fine.
            if exc.args[0].code() != KafkaError.TOPIC_ALREADY_EXISTS:
                raise


def handle(msg):
    """Do something with one message. Right now that is 'log it'.

    Replace the body with real work — this is the seam the rest of the file exists
    to protect: it runs before the offset commit, so a crash in here re-delivers
    the message rather than silently skipping it.
    """
    raw = msg.value().decode("utf-8", errors="replace") if msg.value() else ""
    try:
        payload = json.dumps(json.loads(raw), sort_keys=True)
    except ValueError:
        payload = raw  # not JSON; log it as-is
    key = msg.key().decode("utf-8", errors="replace") if msg.key() else None
    log.info("p%d@%-6d key=%s %s", msg.partition(), msg.offset(), key, payload)


def main():
    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    ensure_topic()

    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP,
            "group.id": GROUP,
            "auto.offset.reset": OFFSET_RESET,
            # Commit after handle() returns, not on a timer, so an unhandled message
            # is never marked as consumed.
            "enable.auto.commit": False,
        }
    )

    def on_assign(_c, parts):
        log.info("assigned: %s", [f"{p.topic}[{p.partition}]" for p in parts] or "nothing")

    def on_revoke(_c, parts):
        log.info("revoked: %s", [f"{p.topic}[{p.partition}]" for p in parts] or "nothing")

    consumer.subscribe([TOPIC], on_assign=on_assign, on_revoke=on_revoke)
    log.info("consuming %r as group %r via %s", TOPIC, GROUP, BOOTSTRAP)

    try:
        while running:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                if msg.error().code() == KafkaError._PARTITION_EOF:
                    continue
                log.error("consume error: %s", msg.error())
                continue
            handle(msg)
            consumer.commit(msg, asynchronous=False)
    finally:
        log.info("closing consumer")
        consumer.close()


if __name__ == "__main__":
    main()
