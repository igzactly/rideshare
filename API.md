## API Reference (Flask)

Base URL: http://<server>:8000

### Health
- GET /healthz — Service liveness probe
  - 200: { "status": "ok" }
- GET /health — Alias of /healthz

### Debug
- GET /__routes__ — List registered routes (debug only)
  - 200: array of { rule, endpoint, methods }

### Rides
- POST /rides or /rides/
  - Description: Create a ride record
  - Body (json): { "pickup": string, "dropoff": string, ... }
  - 201: full created ride document (Mongo fields), with "_id"
  - Example:
```bash
curl -s -X POST http://localhost:8000/rides \
  -H 'Content-Type: application/json' \
  --data-binary '{"pickup":"Point A","dropoff":"Point B"}'
```

- GET /rides/{ride_id}
  - Description: Get a ride by id
  - 200: ride document or 404
  - Example:
```bash
curl -s http://localhost:8000/rides/64a1...c9
```

### Drivers
Driver routes and simple driver profiles/info.

- POST /driver/routes
  - Description: Create a driver route
  - Body: { "driver_id": ObjectId|string, "start_location": [lng,lat], "end_location": [lng,lat], ... }
  - 201: created route document (id in field "id")

- GET /driver/routes?user_id={driverUserId}
  - Description: List driver routes (optionally filter by driver user id)
  - 200: { "routes": [ ... ] }

- POST /driver/rides/{ride_id}/accept
  - Description: Accept a ride as driver
  - Body: { "driver_id": ObjectId|string }
  - 200: { "message": "Ride accepted" } or 404

- PUT /driver/rides/{ride_id}/status
  - Description: Update ride status
  - Body: { "status": "picked_up" | "dropped_off" | "completed" | "cancelled" | "in_progress" }
  - 200: { "message": "Status updated" } or 404

- POST /driver or /driver/
  - Description: Create a driver document (profile/info)
  - Body: arbitrary fields; if "user_id" provided and valid ObjectId string, it will be stored as ObjectId
  - 201: created driver document (id in field "id")

- GET /driver
  - Description: List drivers
  - Query: user_id (optional), limit (default 50, max 200)
  - 200: array of driver docs (id in field "id")

- GET /driver/{driver_id}
  - Description: Get driver by id
  - 200: driver doc or 404

- PUT /driver/{driver_id}
  - Description: Update driver fields
  - Body: partial fields; sets updated_at automatically
  - 200: updated driver doc or 404

- DELETE /driver/{driver_id}
  - Description: Delete driver by id
  - 200: { "deleted": true } or 404

### Payments
- POST /payments/
  - Description: Create a payment record
  - Body: { "user_id": ObjectId|string, "amount": number, "currency": "GBP"|..., "status": "pending"|... }
  - 201: created payment document

- GET /payments/{payment_id}
  - Description: Get payment by id
  - 200: payment document or 404

- PUT /payments/{payment_id}/status
  - Description: Update payment status
  - Body: { "status": "pending" | "completed" | "failed" }
  - 200: updated payment doc or 404

### Safety (Emergency)
- POST /safety/emergency
  - Description: Create emergency alert
  - Body: { "user_id": ObjectId|string, "ride_id"?: ObjectId|string, "emergency_type": string, "location": [lng,lat], ... }
  - 201: created alert document

- GET /safety/emergency/{alert_id}
  - Description: Get emergency alert
  - 200: alert doc or 404

- PUT /safety/emergency/{alert_id}/resolve
  - Description: Resolve emergency alert
  - 200: updated alert doc or 404

- GET /safety/emergency/active
  - Description: List active emergency alerts
  - 200: array of active alerts

### Notes
- Authentication/authorization not yet enforced in Flask; endpoints are open while migration is in progress.
- MongoDB documents will include ObjectId fields; responses generally stringify ObjectIds. For routes created via /driver, response uses field "id" instead of "_id".
- Coordinates are treated as [lng, lat] in the driver routes endpoints.


