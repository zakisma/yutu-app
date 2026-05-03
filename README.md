# Yutu Auction App

Multiplatform Consumer-to-Consumer auction marketplace.
Built as a bachelor's thesis project at VŠFS Praha, 2026.

Backend: Go (Chi + PostgreSQL + Stripe).
Client: Flutter, sharing one codebase across iOS, Android, and web.

## Quick start

Prerequisites:

- Docker and Docker Compose
- Stripe CLI ([install instructions](https://docs.stripe.com/stripe-cli))

Steps:

1. Start Stripe CLI in a separate terminal to forward webhooks:

       stripe listen --forward-to localhost:8080/api/v1/webhooks/stripe

   Stripe CLI prints a `whsec_...` secret. Paste it into
   `STRIPE_WEBHOOK_SECRET` in the root `.env` file.

2. Build and start everything:

       docker compose up --build

3. Open the web client at http://localhost:3000.

## Test card for Stripe

In test mode:
- Card number: 4242 4242 4242 4242
- Expiry: any future date
- CVC: any 3 digits
- ZIP: any 5 digits

## Running tests

    cd backend
    go test -v ./...

(Requires Go 1.25+ installed locally. Tests use sqlmock — no DB needed.)

## License

Bachelor's thesis project — VŠFS Praha 2026.
Author: Abdulaziz Ismoilov.
