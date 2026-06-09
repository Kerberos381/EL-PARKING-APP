const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ── Per-user notification → push to all their registered devices ────────
exports.pushUserNotification = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
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
  "broadcast_notifications/{notifId}",
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
  "bookings/{bookingId}",
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
