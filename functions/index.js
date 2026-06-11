const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── Per-user notification → push to all their registered devices ────────
exports.pushUserNotification = onDocumentCreated(
  { document: "users/{uid}/notifications/{notifId}", maxInstances: 3, region: "europe-west1" },
  async (event) => {
    const { uid } = event.params;
    const data = event.data?.data();
    if (!data?.title || !data?.body) return;

    const userDoc = await db.collection("users").doc(uid).get();
    const tokens = userDoc.data()?.fcmTokens;
    if (!Array.isArray(tokens) || tokens.length === 0) return;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: data.title, body: data.body },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "mutable-content": 1,
          },
        },
      },
    });

    // Remove tokens that FCM says are dead
    const stale = [];
    response.responses.forEach((r, i) => {
      if (
        r.error?.code === "messaging/registration-token-not-registered" ||
        r.error?.code === "messaging/invalid-registration-token"
      ) {
        stale.push(tokens[i]);
      }
    });

    if (stale.length > 0) {
      await db
        .collection("users")
        .doc(uid)
        .update({ fcmTokens: FieldValue.arrayRemove(...stale) });
    }
  }
);

// ── Broadcast notification → fan out to every user with tokens ──────────
exports.pushBroadcast = onDocumentCreated(
  { document: "broadcast_notifications/{notifId}", maxInstances: 3, region: "europe-west1" },
  async (event) => {
    const data = event.data?.data();
    if (!data?.title || !data?.body) return;

    const snapshot = await db.collection("users").get();
    const allTokens = [];
    snapshot.forEach((doc) => {
      const t = doc.data().fcmTokens;
      if (Array.isArray(t)) allTokens.push(...t);
    });

    if (allTokens.length === 0) return;

    const payload = {
      notification: { title: data.title, body: data.body },
      apns: {
        payload: {
          aps: {
            sound: "default",
            "mutable-content": 1,
          },
        },
      },
    };

    // FCM multicast max 500 tokens per call
    for (let i = 0; i < allTokens.length; i += 500) {
      const batch = allTokens.slice(i, i + 500);
      await getMessaging().sendEachForMulticast({ ...payload, tokens: batch });
    }
  }
);

// ── Booking deleted → notify booked user (covers web/admin cancellations) ─
exports.notifyBookingDeleted = onDocumentDeleted(
  { document: "bookings/{bookingId}", maxInstances: 3, region: "europe-west1" },
  async (event) => {
    const data = event.data?.data();
    const email = data?.email;
    const spot = data?.spot;
    const fromTime = data?.fromTime;
    const toTime = data?.toTime;
    const bookingDate = data?.bookingDate;

    if (!email || !spot || !fromTime || !toTime || !bookingDate) return;

    const users = await db.collection("users").where("email", "==", email).limit(1).get();
    if (users.empty) return;

    const uid = users.docs[0].id;

    let dayLabel = "";
    if (typeof bookingDate?.toDate === "function") {
      dayLabel = bookingDate.toDate().toLocaleDateString("en-GB");
    } else if (typeof bookingDate === "string") {
      dayLabel = bookingDate;
    } else {
      dayLabel = "selected day";
    }

    await db
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .add({
        title: "Booking Cancelled",
        body: `Your booking for ${spot} on ${dayLabel} (${fromTime}–${toTime}) was cancelled.`,
        delivered: false,
        createdAt: FieldValue.serverTimestamp(),
      });
  }
);


// ── Admin-only account creation ──────────────────────────────────────────
// Replaces the client-side secondary-app dance: runs with the Admin SDK,
// verifies the caller is an active admin, validates the email domain
// server-side, creates the Auth user + Firestore profile atomically.
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const crypto = require("crypto");

// SHA-256 hashes of allowed email domains (mirrors the app allowlists).
const ALLOWED_DOMAIN_HASHES = new Set([
  "6dcd882bfad5a739cdcc1833e9a8f340233b4db777afb302f615fe30d87ae45c", // essilor.com
  "24ca550ae0c87d8eb8f8d784ec8deb57312af4de6823c1635a509bf69a2b25f4", // essilor.cz
  "3b25ad563a5aa9aa91a73c606016fe635e2c26470da3fa789af7f4d853e244a0", // ext.essilor.com
  "a2fbd416f3c3a7e71506bc88890fe1bb2853afa0e7348395d1ad0da75732e1f8", // luxottica.com
  "1c0d91e0243bd27642ba27cdf1e15f0596e1daefe498a193e5c5ce14e293c476", // essilorluxottica.id
  "e3eadea231b5f76178f350deb37c8b6a1af02fb9786887ad15b9a8d60a18ea07", // omega-optix.cz
]);

exports.adminCreateUser = onCall({ region: "europe-west1", maxInstances: 2 }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const callerDoc = await db.collection("users").doc(callerUid).get();
  const caller = callerDoc.data();
  if (!caller || caller.role !== "admin" || caller.status !== "active") {
    throw new HttpsError("permission-denied", "Only active admins can create users.");
  }

  const name = String(request.data?.name ?? "").trim();
  const email = String(request.data?.email ?? "").trim().toLowerCase();
  const tempPassword = String(request.data?.tempPassword ?? "");
  const role = ["user", "privileged", "admin"].includes(request.data?.role)
    ? request.data.role : "user";
  const companyBadge = ["omega", "essilorLuxottica", "grandVision", "none"]
    .includes(request.data?.companyBadge) ? request.data.companyBadge : "none";

  if (!name) throw new HttpsError("invalid-argument", "Name is required.");
  if (tempPassword.length < 6) {
    throw new HttpsError("invalid-argument", "Temporary password must be at least 6 characters.");
  }
  const domain = email.split("@")[1] ?? "";
  const domainHash = crypto.createHash("sha256").update(domain).digest("hex");
  if (!ALLOWED_DOMAIN_HASHES.has(domainHash)) {
    throw new HttpsError("invalid-argument", "Only allowed company email addresses can be created.");
  }

  let authUser;
  try {
    authUser = await getAuth().createUser({
      email, password: tempPassword, displayName: name,
    });
  } catch (e) {
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "An account with this email already exists.");
    }
    throw new HttpsError("internal", e.message ?? "Account creation failed.");
  }

  const now = FieldValue.serverTimestamp();
  const profile = {
    uid: authUser.uid,
    email,
    displayName: name,
    role,
    status: "active",
    registrationPlate: "",
    carDescription: "",
    carColor: "",
    carType: "",
    vehicleMiniaturePresetID: "",
    preferredVocative: "",
    companyBadge,
    createdAt: now,
    inviteAccepted: true,
    needsFinishRegistration: true,
    emailVerified: true,
    strikes: 0,
    suspensionCount: 0,
  };
  await db.collection("users").doc(authUser.uid).set(profile);

  await db.collection("audit_log").add({
    action: "admin_create_user",
    detail: `Admin created account for ${email} (role: ${role})`,
    performedBy: callerUid,
    targetUID: authUser.uid,
    timestamp: now,
  });

  return { uid: authUser.uid, email, displayName: name, role, companyBadge };
});


// ── HARD COST KILL-SWITCH ────────────────────────────────────────────────
// Google budgets only ALERT — they never stop spending. This function is
// the official pattern for a true cap: a Cloud Billing budget publishes to
// a Pub/Sub topic; when actual cost exceeds the budget, this detaches the
// billing account, instantly reverting the project to free (Spark) quotas.
//
// ONE-TIME SETUP (console, ~5 min, do this right after upgrading to Blaze):
//  1. Google Cloud Console → Billing → Budgets & alerts → Create budget
//     • Amount: $4 (or any cap) • Scope: project el-parking-app
//     • Under "Manage notifications": Connect a Pub/Sub topic →
//       create topic "budget-killswitch" in el-parking-app.
//  2. IAM: grant the function's runtime service account
//     (el-parking-app@appspot.gserviceaccount.com) the role
//     "Billing Account Administrator" ON THE BILLING ACCOUNT
//     (Billing → Account management → Add principal).
//  3. Deploy: firebase deploy --only functions:stopBillingOnBudget
//
// After it fires: functions stop, Firestore reverts to free-tier quotas,
// NO further charges are possible. Re-attach billing manually to recover.
const { onMessagePublished } = require("firebase-functions/v2/pubsub");

exports.stopBillingOnBudget = onMessagePublished(
  { topic: "budget-killswitch", region: "europe-west1", maxInstances: 1 },
  async (event) => {
    const payload = JSON.parse(
      Buffer.from(event.data.message.data, "base64").toString()
    );
    // Budget messages fire repeatedly; only act once cost EXCEEDS the budget.
    if (!payload.costAmount || !payload.budgetAmount) return;
    if (payload.costAmount <= payload.budgetAmount) {
      console.log(`Cost ${payload.costAmount} within budget ${payload.budgetAmount} — no action.`);
      return;
    }

    const { CloudBillingClient } = require("@google-cloud/billing");
    const billing = new CloudBillingClient();
    const name = `projects/${process.env.GCLOUD_PROJECT}`;

    const [info] = await billing.getProjectBillingInfo({ name });
    if (!info.billingEnabled) {
      console.log("Billing already disabled.");
      return;
    }

    await billing.updateProjectBillingInfo({
      name,
      projectBillingInfo: { billingAccountName: "" },
    });
    console.error(
      `KILL-SWITCH FIRED: billing detached at cost ${payload.costAmount} ` +
      `(budget ${payload.budgetAmount}). Project is now on free quotas.`
    );
  }
);
