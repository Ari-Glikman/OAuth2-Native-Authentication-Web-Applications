# Bank OAuth2 demo (IRIS + Keycloak) — scopes + role-gated endpoints

This demo is designed to *feel like OAuth2*:
- Keycloak issues tokens with **scopes** (`bank.balance.read`, `bank.transfer.write`)
- IRIS protects endpoints by checking **IRIS roles**
- Your OAuth2 authenticator (which you’ll implement) maps **token scopes → IRIS roles**

## What’s included
### Keycloak
- Realm: `bank`
- Clients:
  - `bank-demo` (full client; can request `bank.transfer.write`)
  - `bank-monitor` (3rd-party read-only client)
- Users:
  - `user1` / `123`
  - `user2` / `123`

### IRIS
- REST app: `/bank`
  - `GET /bank/checkbalance` (requires role `BankBalanceRead`)
  - `POST /bank/transfer` (requires role `BankTransferWrite`)
- Two IRIS roles are created automatically on container start:
  - `BankBalanceRead`
  - `BankTransferWrite`

> Note: this folder does **not** implement the OAuth authenticator mapping yet.
> You will implement `Bank.Authenticator` to map token scopes to the IRIS roles above.

---

## Prereqs: add a hosts entry (required)
To keep the issuer stable (`iss = http://keycloak:8080/...`) without changing ports or using IPs,
add this entry to your hosts file:

- `127.0.0.1  keycloak`

Hosts file locations:
- Windows: `C:\Windows\System32\drivers\etc\hosts`
- macOS/Linux: `/etc/hosts`

---

## Start
```powershell
New-Item -ItemType Directory -Force .\shared\durable | Out-Null
docker compose up -d --build
```

## URLs
- IRIS Management Portal: `http://localhost:52773/csp/sys/UtilHome.csp`
- Bank API:
  - `http://localhost:52773/bank/checkbalance`
  - `http://localhost:52773/bank/transfer`
- Keycloak: `http://keycloak:8080/keycloak`
  - Realm issuer: `http://keycloak:8080/keycloak/realms/bank`

Keycloak admin: `admin / admin`

---

## Quick sanity check (Basic auth, proves role gating works)
IRIS creates local users for testing:
- `user1` has roles: `BankBalanceRead,BankTransferWrite` (can transfer)
- `user2` has roles: `BankBalanceRead` (cannot transfer)

Try:
- `GET /bank/checkbalance` with user2 → should succeed
- `POST /bank/transfer` with user2 → should return **403** (missing `bank.transfer.write`)

---

## OAuth2 setup in IRIS (after containers are up)
1) **Discover** the Authorization Server:
   - Management Portal → *System Administration > Security > OAuth 2.0 > Client*
   - Create Server Description, Issuer:
     - `http://keycloak:8080/keycloak/realms/bank`
   - Discover + Save

2) Create the **Resource Server**:
   - Allowed audiences: `bank-demo`, `bank-monitor`
   - JWT validation enabled
   - (Optional) Required Scope left blank

3) Enable OAuth2 on the **/bank web application** (IRIS 2025.2+):
   - *System Administration > Security > Applications > Web Applications > /bank*
   - Add OAuth2 as an allowed authentication method
   - Point it at the Resource Server you created

---

## OAuth2 testing (Postman: Authorization Code + PKCE)
Use the Issuer/Authorize/Token endpoints from discovery, and set **Client ID** to:
- `bank-monitor` for read-only third-party
- `bank-demo` for full access

Scopes to request:
- Read-only:
  - `openid profile email bank.balance.read`
- Full:
  - `openid profile email bank.balance.read bank.transfer.write`

> Once you implement `Bank.Authenticator` to map token scopes → IRIS roles, the behavior will be:
> - `bank-monitor` token can call `/checkbalance` but not `/transfer`
> - `bank-demo` token can call both (if it has `bank.transfer.write`)
