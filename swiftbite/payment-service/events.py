import json, os, threading
import pika
URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
EXCHANGE = os.getenv("RABBITMQ_EXCHANGE", "swiftbite.events")
def _pub(key, body):
    try:
        p = pika.URLParameters(URL); p.socket_timeout = 2; p.connection_attempts = 1
        c = pika.BlockingConnection(p); ch = c.channel()
        ch.exchange_declare(EXCHANGE, "topic", durable=True)
        ch.basic_publish(EXCHANGE, key, json.dumps(body)); c.close()
    except Exception as e:
        print("event not published:", key, e, flush=True)
def publish(key, body): threading.Thread(target=_pub, args=(key, body), daemon=True).start()
