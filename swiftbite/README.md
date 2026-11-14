# SwiftBite: 14 services

Run everything locally: `docker compose up --build`, then open http://localhost:3000
Test login: promise@example.com / 1234 (any role).

| service | port | image build context | key env vars |
|---|---|---|---|
| frontend (nginx) | 80 | ./frontend | API_GATEWAY_URL (default http://api-gateway:8000) |
| api-gateway | 8000 | ./api-gateway | ROUTES_JSON (optional, overrides all routes) |
| auth-service | 8001 | ./auth-service | |
| user-service | 8002 | ./user-service | |
| cart-service | 8003 | ./cart-service | |
| order-service | 8005 | ./order-service | DELIVERY_URL, RABBITMQ_URL |
| payment-service | 8006 | ./payment-service | RABBITMQ_URL |
| restaurant-service | 8007 | ./restaurant-service | |
| search-service | 8008 | ./search-service | RESTAURANT_URL, MENU_URL |
| menu-service | 8009 | ./menu-service | |
| review-service | 8010 | ./review-service | |
| notification-service | 8011 | ./notification-service | RABBITMQ_URL |
| delivery-service | 8012 | ./delivery-service | ORDER_URL |
| analytics-service | 8013 | ./analytics-service | ORDER_URL |

Kubernetes: name each Service exactly like the folder (e.g. `order-service`) and the built-in defaults
work with no env changes. Probes: GET /health and /ready on every service (frontend: /healthz).
RabbitMQ is the only extra dependency (`RABBITMQ_URL=amqp://user:pass@rabbitmq:5672/`); without it
everything still works, you just don't get notifications.

## Order flow
PLACED -> restaurant accepts (order-service calls delivery-service, a rider is assigned) -> rider picks up -> delivered.
Each status change publishes an event on exchange `swiftbite.events` that notification-service turns into email/SMS logs.

## Limits
- All state is in memory (matches your mocks): run 1 replica per service, data resets on restart.
- Tokens are mock (`mock-jwt-token-<id>`); services don't validate them yet.
- Delivery WebSocket is at /delivery/ws/{order_id} on delivery-service. It is not proxied by the gateway; expose it via ingress if you want it. The UI polls instead.
