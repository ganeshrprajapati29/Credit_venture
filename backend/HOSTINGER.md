# Deploy the Credit Ventures API on Hostinger (Node.js app)

## 1. Database (MongoDB Atlas – free)
Hostinger Node.js hosting does not include MongoDB, so use MongoDB Atlas:
1. https://www.mongodb.com/atlas → create a free cluster.
2. **Database Access** → add a user + password.
3. **Network Access** → *Allow access from anywhere* (`0.0.0.0/0`) – Hostinger IPs can change.
4. **Connect → Drivers** → copy the connection string and put `credit_ventures` as the database name:
   `mongodb+srv://USER:PASSWORD@cluster0.xxxxx.mongodb.net/credit_ventures?retryWrites=true&w=majority`

## 2. Create the Node.js app in hPanel
1. hPanel → **Websites** → your domain/subdomain (e.g. `api.yourdomain.com`) → **Node.js** (or *Add website → Node.js app*).
2. Upload `credit-ventures-backend.zip` (or extract it into the app folder with File Manager).
3. Settings:
   - **Node.js version:** 20 or 22
   - **Framework:** Express (or *Other*)
   - **Entry file:** `server.js`
   - **Install / build command:** `npm install` (no build step)
   - **Start command:** `npm start`
4. **Environment variables:** add every line from `.env.example` with real values
   (at minimum `NODE_ENV`, `MONGO_URI`, `JWT_SECRET`, `JWT_ADMIN_SECRET`, `CORS_ORIGINS`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`).
   Do **not** set `PORT` – Hostinger provides it. A ready file `.env.production` with random JWT secrets is included in the zip; copy its values.
5. Deploy / Restart the app.

## 3. Check it is running
- `https://api.yourdomain.com/api/v1/health` → `"status": "ok"` and `"database": { "status": "connected" }` (HTTP 200)
- `https://api.yourdomain.com/health/live` → `"status": "alive"` (process is up)
- If health shows `"degraded"` / database `connecting`, the `MONGO_URI` or Atlas network access is wrong – check the app logs in hPanel.

## 4. Connect the admin panel and the app
- Admin panel: build with `VITE_API_URL=https://api.yourdomain.com/api/v1` and put that URL in `CORS_ORIGINS`.
- Android app: build with `--dart-define=API_URL=https://api.yourdomain.com/api/v1`
  (or set the GitHub repository variable `API_URL` and re-run *Build Android APK*).

## Notes
- On the first start the API creates the super admin from `ADMIN_EMAIL` / `ADMIN_PASSWORD`, default settings and banners.
- Uploaded documents are saved in `uploads/` inside the app folder (or `UPLOAD_DIR`). Back this folder up and keep it when you redeploy.
- Logs: hPanel → Node.js app → Logs.
