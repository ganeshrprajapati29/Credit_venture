# Credit Ventures

A complete digital personal-loan platform:

| Part | Tech | Folder |
|------|------|--------|
| Customer mobile app | Flutter (Android) | [`app/`](app) |
| REST API | Node.js, Express, MongoDB | [`backend/`](backend) |
| Admin panel | React + Vite + Tailwind | [`admin/`](admin) |
| VPS deployment | Nginx, PM2, Let's Encrypt | [`deploy/`](deploy) |

Everything in the app (loan limits, interest, tenures, fees, dropdown options, banners, support details, repayment bank/UPI details, maintenance mode, force-update) is **dynamic** and controlled from the admin panel.

KYC and bank verification are **manual** – no third-party API is used. Customers type their Aadhaar / PAN / bank details and upload photos; your team verifies them in the admin panel.

---

## Customer journey (mobile app)

1. Splash → onboarding → **privacy & permission disclosure** (camera, optional location, notifications)
2. Mobile number → create / enter **4-digit MPIN**
3. Home: loan offer card, banner carousel, how-it-works, EMI calculator, support
4. Application (8 steps, resumable at any time)
   1. Basic details + credit-bureau & CKYC consent → instant eligibility & offer
   2. Choose amount (slider) & tenure → EMI, fee, GST, net disbursal
   3. Personal details (parents, residence, purpose, language, PEP declaration)
   4. Company / business details
   5. Current & permanent address
   6. KYC – Aadhaar no. (checksum validated), PAN, Aadhaar front/back, PAN card, live selfie, salary slip
   7. Bank account (account no., IFSC, cancelled cheque / passbook upload)
   8. Key Fact Statement with APR + loan agreement → e-sign by typing full name
5. Track status: Submitted → Verification → Approved → Disbursed
6. EMI schedule, pay EMI manually (UPI / NEFT) and upload screenshot + UTR
7. In-app notifications, profile, change MPIN, help & grievance officer

### Permissions

The app requests only **Camera**, **Location (optional)** and **Notifications**, after a full disclosure screen. It does **not** read SMS, contacts, call logs or gallery – RBI's Digital Lending Directions prohibit lending apps from accessing these, and Google Play rejects personal-loan apps that do.

## Admin panel

- Dashboard: applications, approvals, active loans, disbursed amount, EMI collected, overdue, 14-day trend
- Loan applications: search / filter, full applicant view, private document viewer, verification checklist, internal remarks, approve (edit amount / tenure / rate / fee), reject with reason, record disbursal (UTR) → auto EMI schedule, mark EMIs paid, close loan, timeline
- EMI payments: verify / reject customer payment proofs (auto-marks EMI paid and closes the loan when complete)
- Customers: block / unblock, reset MPIN, loan history, device & consent info
- App banners (image or colour + text), in-app notifications (single user or broadcast)
- App settings: loan product, company & support, repayment account, all dropdown lists, terms / privacy, app version & maintenance
- Team & roles: `superadmin`, `manager`, `verifier`

---

## Run locally

```bash
# 1. API (needs MongoDB running locally)
cd backend
cp .env.example .env        # edit values
npm install
npm run dev                 # http://localhost:5000/api/v1/health

# 2. Admin panel
cd admin
npm install
npm run dev                 # http://localhost:5173  (proxies /api to :5000)

# 3. Mobile app
cd app
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:5000/api/v1   # Android emulator
```

On first start the API creates the super admin from `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `.env` (default `admin@creditventures.in` / `Admin@12345` – change it!) plus default settings and banners.

---

## Deploy on a VPS (Ubuntu 22.04 / 24.04)

1. Buy a domain and create two DNS **A records** pointing to the VPS IP, e.g. `api.yourdomain.com` and `admin.yourdomain.com`.
2. On the VPS:

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/ganeshrprajapati29/Credit_venture.git /opt/credit-ventures
cd /opt/credit-ventures
sudo API_DOMAIN=api.yourdomain.com ADMIN_DOMAIN=admin.yourdomain.com \
     LETSENCRYPT_EMAIL=you@yourdomain.com bash deploy/setup-vps.sh
```

The script installs Node 22, MongoDB 8, Nginx, PM2 and Certbot, generates secrets in `backend/.env`, builds the admin panel, configures Nginx + HTTPS, starts the API with PM2, enables the firewall and a daily backup (`/var/backups/credit-ventures`). It prints the first admin password at the end.

To update later: `sudo API_DOMAIN=api.yourdomain.com bash deploy/update.sh`

---

## Build the APK

### Option A – GitHub Actions (no setup needed)

Every push that changes `app/` runs **Actions → Build Android APK**. The APK is attached to a new **GitHub Release** and uploaded as a workflow artifact.

To point the app at your server:

- Repo **Settings → Secrets and variables → Actions → Variables** → add `API_URL` = `https://api.yourdomain.com/api/v1`, **or**
- **Actions → Build Android APK → Run workflow** and fill in `api_url`.

For a permanent release key (needed to publish updates over an installed app / Play Store) add these repository **secrets**:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | key alias |
| `ANDROID_KEY_PASSWORD` | key password |

Create a keystore with:
`keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias creditventures`

Without these secrets the APK is signed with a debug key (fine for testing).

### Option B – your computer

```bash
cd app
flutter build apk --release --dart-define=API_URL=https://api.yourdomain.com/api/v1
# output: app/build/app/outputs/flutter-apk/app-release.apk
```

---

## Before going live (important)

- Lending money in India requires an **RBI licence (NBFC)** or a tie-up with an RBI-regulated lender. Add the lender name, registration number and grievance officer in **App settings → Company & support** – the app shows them to customers as required by RBI's Digital Lending Directions.
- Fill in Terms of Service and Privacy Policy (App settings → Legal).
- Change the default admin password, and add your repayment bank / UPI details.
- KYC documents are stored in `UPLOAD_DIR/private` and are only served through an authenticated endpoint. Keep backups encrypted and restrict VPS access.

## API overview

Base URL: `/api/v1` · all responses: `{ success, message, data }`

| Area | Endpoints |
|------|-----------|
| Public | `GET /health`, `GET /app/config`, `GET /app/banners` |
| Auth | `POST /auth/check`, `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `PUT /auth/profile`, `PUT /auth/mpin`, `PUT /auth/device` |
| Application | `PUT /loans/current/{basic,offer,personal,employment,address,kyc,bank}`, `POST /loans/current/submit`, `GET /loans/quote`, `GET /loans/current`, `GET /loans`, `GET /loans/:id`, `POST /loans/:id/cancel`, `POST /loans/:id/payments` |
| Other | `GET /notifications`, `PUT /notifications/:id/read`, `GET /files/:name` (auth) |
| Admin | `/admin/auth/*`, `/admin/dashboard`, `/admin/loans/*`, `/admin/payments/*`, `/admin/users/*`, `/admin/settings`, `/admin/banners/*`, `/admin/notifications/*`, `/admin/team/*` |
