import { initializeApp } from "https://www.gstatic.com/firebasejs/11.7.1/firebase-app.js";
import {
  browserSessionPersistence,
  getAuth,
  onAuthStateChanged,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-auth.js";
import {
  collection,
  doc,
  getDoc,
  getFirestore,
  onSnapshot,
  runTransaction,
  serverTimestamp,
  Timestamp,
  updateDoc,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-firestore.js";
import { firebaseConfig } from "./firebase-config.js";

const APP_RULES = {
  selfBookingMaxAdvanceDays: 3,
  selfBookingMaxPerDay: 1,
  bookingRetentionDays: 2,
};

const state = {
  user: null,
  profile: null,
  selectedDate: toYmd(new Date()),
  selectedSpotLabel: "",
  spots: [],
  allBookings: [],
  dayBookings: [],
  myBookings: [],
  announcements: [],
  listeners: {
    allBookings: null,
    spots: null,
    announcements: null,
    users: null,
  },
};

const ui = {
  authView: byId("authView"),
  appView: byId("appView"),
  pendingView: byId("pendingView"),
  authError: byId("authError"),
  loginForm: byId("loginForm"),
  loginButton: byId("loginButton"),
  emailInput: byId("emailInput"),
  passwordInput: byId("passwordInput"),
  pendingSignOut: byId("pendingSignOut"),
  signOutButton: byId("signOutButton"),
  greetingText: byId("greetingText"),
  heroState: byId("heroState"),
  heroDate: byId("heroDate"),
  heroSpot: byId("heroSpot"),
  heroTime: byId("heroTime"),
  announcementsList: byId("announcementsList"),
  refreshHome: byId("refreshHome"),
  parkingDateInput: byId("parkingDateInput"),
  dayPills: byId("dayPills"),
  freeCount: byId("freeCount"),
  bookedCount: byId("bookedCount"),
  blockedCount: byId("blockedCount"),
  spotsGrid: byId("spotsGrid"),
  bookForm: byId("bookForm"),
  selectedSpotDisplay: byId("selectedSpotDisplay"),
  spotSelect: byId("spotSelect"),
  bookDate: byId("bookDate"),
  bookFrom: byId("bookFrom"),
  bookTo: byId("bookTo"),
  bookButton: byId("bookButton"),
  bookError: byId("bookError"),
  myBookingsList: byId("myBookingsList"),
  refreshBookings: byId("refreshBookings"),
  adminTab: byId("adminTab"),
  usersTotal: byId("usersTotal"),
  usersActive: byId("usersActive"),
  usersPending: byId("usersPending"),
  profileForm: byId("profileForm"),
  nameInput: byId("nameInput"),
  vocativeInput: byId("vocativeInput"),
  plateInput: byId("plateInput"),
  carInput: byId("carInput"),
  profileError: byId("profileError"),
  saveProfileBtn: byId("saveProfileBtn"),
  tabs: [...document.querySelectorAll(".tab")],
  tabPanels: {
    home: byId("homeTab"),
    parking: byId("parkingTab"),
    bookings: byId("bookingsTab"),
    admin: byId("adminTabPanel"),
    settings: byId("settingsTab"),
  },
  bookingTemplate: byId("bookingRowTemplate"),
};

let auth;
let db;

boot();

async function boot() {
  ui.loginForm.addEventListener("submit", (event) => event.preventDefault(), { capture: true });
  try {
    const app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    db = getFirestore(app);
    try {
      await setPersistence(auth, browserSessionPersistence);
    } catch (persistError) {
      console.warn("setPersistence failed, fallback to default:", persistError);
    }
    bootstrap();
  } catch (error) {
    console.error("Web bootstrap failed:", error);
    ui.authError.textContent =
      "Initialization failed. Open browser console and send the first red error line.";
    ui.loginButton.disabled = true;
  }
}

function bootstrap() {
  ui.parkingDateInput.value = state.selectedDate;
  ui.bookDate.value = state.selectedDate;
  bindEvents();
  onAuthStateChanged(auth, handleAuthState);
}

function bindEvents() {
  ui.loginForm.addEventListener("submit", onLoginSubmit);
  ui.signOutButton.addEventListener("click", () => signOut(auth));
  ui.pendingSignOut.addEventListener("click", () => signOut(auth));
  ui.refreshHome.addEventListener("click", () => renderAnnouncements());
  ui.refreshBookings.addEventListener("click", () => renderMyBookings());

  ui.parkingDateInput.addEventListener("change", () => {
    state.selectedDate = ui.parkingDateInput.value || toYmd(new Date());
    ui.bookDate.value = state.selectedDate;
    recalculateDerivedBookings();
    renderParking();
    renderDayPills();
  });

  ui.bookDate.addEventListener("change", () => {
    state.selectedDate = ui.bookDate.value || state.selectedDate;
    ui.parkingDateInput.value = state.selectedDate;
    recalculateDerivedBookings();
    renderParking();
    renderDayPills();
  });

  ui.spotSelect.addEventListener("change", () => {
    if (!ui.spotSelect.value) return;
    setSelectedSpot(ui.spotSelect.value);
    renderParking();
  });

  ui.bookForm.addEventListener("submit", onBookSubmit);
  ui.profileForm.addEventListener("submit", onSaveProfile);
  ui.tabs.forEach((tab) => tab.addEventListener("click", () => switchTab(tab.dataset.tab)));
}

async function handleAuthState(user) {
  clearAllListeners();
  state.user = user;
  state.profile = null;
  state.spots = [];
  state.allBookings = [];
  state.dayBookings = [];
  state.myBookings = [];
  state.announcements = [];
  state.selectedSpotLabel = "";

  if (!user) {
    showOnly("auth");
    ui.authError.textContent = "";
    ui.passwordInput.value = "";
    return;
  }

  const profileSnap = await getDoc(doc(db, "users", user.uid));
  if (!profileSnap.exists()) {
    await signOut(auth);
    ui.authError.textContent = "User profile not found.";
    return;
  }

  state.profile = parseUser(profileSnap.data());
  const role = (state.profile.role || "user").toLowerCase();
  const status = (state.profile.status || "pending").toLowerCase();

  if (status !== "active") {
    showOnly("pending");
    return;
  }

  showOnly("app");
  ui.adminTab.classList.toggle("hidden", !(role === "admin" || role === "privileged"));
  if (role !== "admin" && role !== "privileged" && currentTab() === "admin") {
    switchTab("home");
  }

  hydrateProfileForm();
  renderGreeting();
  switchTab("home");
  subscribeCoreData();
}

async function onLoginSubmit(event) {
  event.preventDefault();
  ui.authError.textContent = "";
  const email = ui.emailInput.value.trim().toLowerCase();
  const password = ui.passwordInput.value;

  if (!email || password.length < 6) {
    ui.authError.textContent = "Use a valid email and password.";
    return;
  }

  ui.loginButton.disabled = true;
  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (err) {
    ui.authError.textContent = friendlyAuthError(err);
  } finally {
    ui.loginButton.disabled = false;
  }
}

function subscribeCoreData() {
  subscribeSpots();
  subscribeAllBookings();
  subscribeAnnouncements();
  subscribeAdminStatsIfAllowed();
}

function subscribeSpots() {
  state.listeners.spots?.();
  state.listeners.spots = onSnapshot(
    collection(db, "parkingSpots"),
    (snap) => {
      state.spots = snap.docs
        .map((d) => parseSpot(d.id, d.data()))
        .sort((a, b) => (a.sortOrder ?? 999) - (b.sortOrder ?? 999) || compareNumberString(a.id, b.id));
      renderSpotSelect();
      ensureSelectedSpotIsValid();
      recalculateDerivedBookings();
      renderParking();
      renderDayPills();
    },
    () => {
      state.spots = [];
      renderSpotSelect();
      recalculateDerivedBookings();
      renderParking();
      renderDayPills();
    }
  );
}

function subscribeAllBookings() {
  state.listeners.allBookings?.();
  state.listeners.allBookings = onSnapshot(
    collection(db, "bookings"),
    (snap) => {
      const loaded = snap.docs
        .map((d) => parseBooking(d.id, d.data()))
        .filter(Boolean)
        .filter(shouldKeepBookingLocally)
        .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime());
      state.allBookings = loaded;
      recalculateDerivedBookings();
      renderHomeHero();
      renderMyBookings();
      renderParking();
      renderDayPills();
    },
    () => {
      state.allBookings = [];
      recalculateDerivedBookings();
      renderHomeHero();
      renderMyBookings();
      renderParking();
      renderDayPills();
    }
  );
}

function subscribeAnnouncements() {
  state.listeners.announcements?.();
  state.listeners.announcements = onSnapshot(
    collection(db, "announcements"),
    (snap) => {
      state.announcements = snap.docs
        .map((d) => parseAnnouncement(d.id, d.data()))
        .filter((item) => item?.isActive)
        .sort((a, b) => (b.createdAtMs || 0) - (a.createdAtMs || 0))
        .slice(0, 12);
      renderAnnouncements();
    },
    () => {
      state.announcements = [];
      renderAnnouncements();
    }
  );
}

function subscribeAdminStatsIfAllowed() {
  state.listeners.users?.();
  if (!state.profile || !["admin", "privileged"].includes((state.profile.role || "").toLowerCase())) {
    return;
  }
  state.listeners.users = onSnapshot(collection(db, "users"), (snap) => {
    const users = snap.docs.map((d) => parseUser(d.data()));
    ui.usersTotal.textContent = String(users.length);
    ui.usersActive.textContent = String(users.filter((u) => (u.status || "").toLowerCase() === "active").length);
    ui.usersPending.textContent = String(users.filter((u) => (u.status || "").toLowerCase() === "pending").length);
  });
}

function recalculateDerivedBookings() {
  const dayKey = state.selectedDate;
  state.dayBookings = state.allBookings.filter((booking) => toYmd(booking.bookingDate) === dayKey);
  state.myBookings = state.allBookings.filter((booking) => isBookingForCurrentUser(booking));
}

function renderGreeting() {
  const name =
    (state.profile?.preferredVocative || "").trim() ||
    firstName(state.profile?.displayName || state.user?.email || "there");
  ui.greetingText.textContent = `Hello, ${name}`;
}

function renderHomeHero() {
  const now = new Date();
  const todayKey = toYmd(now);
  const upcoming = state.myBookings
    .slice()
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime())
    .find((b) => toYmd(b.bookingDate) >= todayKey);

  if (!upcoming) {
    ui.heroState.textContent = "NO BOOKING";
    ui.heroDate.textContent = "";
    ui.heroSpot.textContent = "--";
    ui.heroTime.textContent = "Book your next place";
    return;
  }

  const isToday = toYmd(upcoming.bookingDate) === todayKey;
  const isTomorrow = toYmd(upcoming.bookingDate) === toYmd(addDays(now, 1));
  const lead = isToday ? "Today" : isTomorrow ? "Tomorrow" : "Upcoming";
  ui.heroState.textContent = isToday ? "ACTIVE" : "UPCOMING";
  ui.heroDate.textContent = `${lead} · ${formatShortDate(upcoming.bookingDate)}`;
  ui.heroSpot.textContent = String(extractSpotNumber(upcoming.spot));
  ui.heroTime.textContent = `${upcoming.fromTime} - ${upcoming.toTime}`;
}

function renderAnnouncements() {
  ui.announcementsList.textContent = "";
  const pinned = state.announcements.filter((a) => a.isPinned);
  const list = pinned.length ? pinned : state.announcements;

  if (!list.length) {
    ui.announcementsList.append(textRow("No active announcements."));
    return;
  }

  for (const item of list) {
    const wrap = document.createElement("article");
    wrap.className = "announcement";

    if (item.imageURL) {
      const img = document.createElement("img");
      img.className = "announcement-media";
      img.loading = "lazy";
      img.decoding = "async";
      img.src = item.imageURL;
      img.alt = item.title || "Announcement image";
      wrap.append(img);
    }

    const body = document.createElement("div");
    body.className = "announcement-body";
    const h = document.createElement("h4");
    h.textContent = `${item.emoji || "📣"} ${item.title}`;
    const p = document.createElement("p");
    p.textContent = item.body || "";
    body.append(h, p);
    wrap.append(body);

    ui.announcementsList.append(wrap);
  }
}

function renderDayPills() {
  ui.dayPills.textContent = "";
  const start = dayStart(toYmd(new Date()));
  for (let i = 0; i < 7; i += 1) {
    const date = addDays(start, i);
    const ymd = toYmd(date);
    const bookings = state.allBookings.filter((booking) => toYmd(booking.bookingDate) === ymd);
    const occupancy = dayOccupancyPercent(bookings);

    const button = document.createElement("button");
    button.type = "button";
    button.className = "day-pill";
    button.classList.toggle("active", ymd === state.selectedDate);
    button.innerHTML = `
      <strong>${ymd === toYmd(new Date()) ? "Today" : weekdayShort(date)}</strong>
      <span>${date.getDate()}</span>
      <small>${occupancy}% used</small>
    `;
    button.addEventListener("click", () => {
      state.selectedDate = ymd;
      ui.parkingDateInput.value = ymd;
      ui.bookDate.value = ymd;
      recalculateDerivedBookings();
      renderParking();
      renderDayPills();
    });
    ui.dayPills.append(button);
  }
}

function renderSpotSelect() {
  ui.spotSelect.textContent = "";
  const placeholder = document.createElement("option");
  placeholder.value = "";
  placeholder.textContent = "Select spot";
  ui.spotSelect.append(placeholder);

  const available = state.spots.filter((spot) => !spot.isBlocked);
  for (const spot of available) {
    const option = document.createElement("option");
    option.value = spot.label;
    option.textContent = spot.label;
    ui.spotSelect.append(option);
  }
}

function renderParking() {
  const blockedKeys = new Set(state.spots.filter((s) => s.isBlocked).map((s) => normalizedSpotKey(s.label)));
  const bookedKeys = new Set(state.dayBookings.map((b) => normalizedSpotKey(b.spot)));
  const usable = state.spots.filter((s) => !s.isBlocked);
  const uniqueBookedUsable = new Set(
    state.dayBookings
      .map((b) => normalizedSpotKey(b.spot))
      .filter((k) => !blockedKeys.has(k))
  );

  ui.freeCount.textContent = String(Math.max(usable.length - uniqueBookedUsable.size, 0));
  ui.bookedCount.textContent = String(uniqueBookedUsable.size);
  ui.blockedCount.textContent = String(state.spots.length - usable.length);

  ui.spotsGrid.textContent = "";
  for (const spot of state.spots) {
    const key = normalizedSpotKey(spot.label);
    let stateName = "free";
    if (spot.isBlocked) stateName = "blocked";
    else if (bookedKeys.has(key)) stateName = "booked";

    const cell = document.createElement("button");
    cell.type = "button";
    cell.className = "spot-cell";
    cell.dataset.state = stateName;
    cell.classList.toggle("selected", normalizedSpotKey(state.selectedSpotLabel) === key);

    const strong = document.createElement("strong");
    strong.textContent = String(extractSpotNumber(spot.label));
    const small = document.createElement("small");
    small.textContent = stateName === "free" ? "FREE" : stateName === "booked" ? "BOOKED" : "BLOCKED";
    cell.append(strong, small);

    if (stateName === "free") {
      cell.addEventListener("click", () => {
        setSelectedSpot(spot.label);
        renderParking();
      });
    }

    ui.spotsGrid.append(cell);
  }

  ui.selectedSpotDisplay.value = state.selectedSpotLabel || "";
}

function renderMyBookings() {
  ui.myBookingsList.textContent = "";
  const upcoming = state.myBookings
    .slice()
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime())
    .filter((b) => bookingEndDate(b.bookingDate, b.toTime) >= new Date());

  if (!upcoming.length) {
    ui.myBookingsList.append(textRow("No upcoming bookings."));
    renderHomeHero();
    return;
  }

  for (const booking of upcoming) {
    const node = ui.bookingTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".title").textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(
      booking.bookingDate
    )}`;
    node.querySelector(".meta").textContent = `${booking.fromTime} - ${booking.toTime}`;
    const cancel = node.querySelector("button");
    cancel.addEventListener("click", () => cancelBooking(booking));
    ui.myBookingsList.append(node);
  }

  renderHomeHero();
}

async function onBookSubmit(event) {
  event.preventDefault();
  ui.bookError.textContent = "";
  if (!state.user || !state.profile) return;

  const spot = ui.spotSelect.value || state.selectedSpotLabel;
  const dateYmd = ui.bookDate.value;
  const fromTime = ui.bookFrom.value;
  const toTime = ui.bookTo.value;

  if (!spot || !dateYmd || !fromTime || !toTime || fromTime >= toTime) {
    ui.bookError.textContent = "Check date, time range and selected spot.";
    return;
  }

  ui.bookButton.disabled = true;
  try {
    const date = dayStart(dateYmd);
    enforceBookingRules(spot, dateYmd, fromTime, toTime);
    await createBookingTransaction(spot, date, dateYmd, fromTime, toTime);
    setSelectedSpot("");
    ui.bookError.textContent = "";
  } catch (err) {
    ui.bookError.textContent = err?.message || "Could not create booking.";
  } finally {
    ui.bookButton.disabled = false;
  }
}

function enforceBookingRules(spotLabel, dateYmd, fromTime, toTime) {
  if (fromTime >= toTime) throw new Error("Invalid time range.");

  const blocked = state.spots.some(
    (spot) => spot.isBlocked && normalizedSpotKey(spot.label) === normalizedSpotKey(spotLabel)
  );
  if (blocked) throw new Error("This spot is blocked.");

  const todayStart = dayStart(toYmd(new Date()));
  const targetDate = dayStart(dateYmd);
  const advanceDays = Math.round((targetDate.getTime() - todayStart.getTime()) / 86400000);
  if (advanceDays > APP_RULES.selfBookingMaxAdvanceDays) {
    throw new Error(`You can book max ${APP_RULES.selfBookingMaxAdvanceDays} days in advance.`);
  }

  const mySameDayCount = state.myBookings.filter((booking) => toYmd(booking.bookingDate) === dateYmd).length;
  if (mySameDayCount >= APP_RULES.selfBookingMaxPerDay) {
    throw new Error("You can book only 1 spot per day.");
  }

  const normalizedRequested = normalizedSpotKey(spotLabel);
  const conflict = state.allBookings
    .filter((booking) => toYmd(booking.bookingDate) === dateYmd)
    .filter((booking) => normalizedSpotKey(booking.spot) === normalizedRequested)
    .some((booking) => timesOverlap(fromTime, toTime, booking.fromTime, booking.toTime));
  if (conflict) throw new Error("This spot is already booked in that time range.");
}

async function createBookingTransaction(spotLabel, bookingDate, dateYmd, fromTime, toTime) {
  const bookingRef = doc(collection(db, "bookings"));
  const lockRef = doc(db, "spot_locks", `${spotLabel}_${dateYmd}`);
  const email = state.user.email.toLowerCase();
  const displayName = state.profile.displayName || email;
  const spotDoc = state.spots.find((spot) => normalizedSpotKey(spot.label) === normalizedSpotKey(spotLabel));
  const expiresAt = addDays(bookingEndDate(bookingDate, toTime), APP_RULES.bookingRetentionDays);

  await runTransaction(db, async (transaction) => {
    const lockSnap = await transaction.get(lockRef);
    const slots = lockSnap.data()?.slots ?? [];

    for (const slot of slots) {
      const sFrom = String(slot.from || "");
      const sTo = String(slot.to || "");
      if (!sFrom || !sTo) continue;
      if (timesOverlap(fromTime, toTime, sFrom, sTo)) {
        throw new Error("This spot is already booked in that time range.");
      }
    }

    const bookingPayload = {
      id: bookingRef.id,
      title: `Reservation for ${displayName}`,
      spot: spotLabel,
      spotID: spotDoc?.id || extractSpotNumber(spotLabel),
      user: displayName,
      email,
      bookedForUid: state.user.uid,
      fromTime,
      toTime,
      createdBy: email,
      bookingDate: Timestamp.fromDate(bookingDate),
      createdAt: serverTimestamp(),
      expiresAt: Timestamp.fromDate(expiresAt),
    };

    transaction.set(bookingRef, bookingPayload);
    transaction.set(
      lockRef,
      {
        slots: [...slots, { from: fromTime, to: toTime, bookingId: bookingRef.id }],
      },
      { merge: true }
    );
  });
}

async function cancelBooking(booking) {
  if (!state.user || !state.profile) return;
  const ok = window.confirm(
    `Cancel booking for spot ${extractSpotNumber(booking.spot)} on ${formatLongDate(booking.bookingDate)}?`
  );
  if (!ok) return;

  try {
    const myEmail = String(state.user.email || "").trim().toLowerCase();
    const role = (state.profile.role || "").toLowerCase();
    const ownerEmail = String(booking.email || "").trim().toLowerCase();
    if (myEmail !== ownerEmail && role !== "admin" && role !== "privileged") {
      throw new Error("You can cancel only your own bookings.");
    }

    const bookingDateKey = toYmd(booking.bookingDate);
    const lockRef = doc(db, "spot_locks", `${booking.spot}_${bookingDateKey}`);
    const bookingRef = doc(db, "bookings", booking.id);

    await runTransaction(db, async (transaction) => {
      const lockSnap = await transaction.get(lockRef);
      if (lockSnap.exists()) {
        const slots = lockSnap.data()?.slots ?? [];
        const updated = slots.filter((slot) => String(slot.bookingId || "") !== booking.id);
        transaction.set(lockRef, { slots: updated }, { merge: true });
      }
      transaction.delete(bookingRef);
    });
  } catch (err) {
    alert(err?.message || "Cancel failed.");
  }
}

async function onSaveProfile(event) {
  event.preventDefault();
  ui.profileError.textContent = "";
  if (!state.user || !state.profile) return;

  const displayName = ui.nameInput.value.trim();
  const preferredVocative = ui.vocativeInput.value.trim();
  const registrationPlate = ui.plateInput.value.trim().toUpperCase();
  const carDescription = ui.carInput.value.trim();

  if (displayName.length < 2) {
    ui.profileError.textContent = "Display name is too short.";
    return;
  }

  ui.saveProfileBtn.disabled = true;
  try {
    await updateDoc(doc(db, "users", state.user.uid), {
      displayName,
      preferredVocative,
      registrationPlate,
      carDescription,
    });
    state.profile = { ...state.profile, displayName, preferredVocative, registrationPlate, carDescription };
    renderGreeting();
  } catch {
    ui.profileError.textContent = "Save failed.";
  } finally {
    ui.saveProfileBtn.disabled = false;
  }
}

function hydrateProfileForm() {
  ui.nameInput.value = state.profile?.displayName || "";
  ui.vocativeInput.value = state.profile?.preferredVocative || "";
  ui.plateInput.value = state.profile?.registrationPlate || "";
  ui.carInput.value = state.profile?.carDescription || "";
}

function switchTab(tab) {
  if (!tab) return;
  for (const [name, panel] of Object.entries(ui.tabPanels)) {
    panel.classList.toggle("hidden", name !== tab);
  }
  for (const btn of ui.tabs) {
    btn.classList.toggle("active", btn.dataset.tab === tab);
  }
}

function currentTab() {
  return ui.tabs.find((tab) => tab.classList.contains("active"))?.dataset.tab || "home";
}

function showOnly(mode) {
  ui.authView.classList.toggle("hidden", mode !== "auth");
  ui.appView.classList.toggle("hidden", mode !== "app");
  ui.pendingView.classList.toggle("hidden", mode !== "pending");
}

function clearAllListeners() {
  Object.keys(state.listeners).forEach((key) => {
    if (typeof state.listeners[key] === "function") state.listeners[key]();
    state.listeners[key] = null;
  });
}

function setSelectedSpot(label) {
  state.selectedSpotLabel = label || "";
  ui.spotSelect.value = label || "";
  ui.selectedSpotDisplay.value = label || "";
}

function ensureSelectedSpotIsValid() {
  if (!state.selectedSpotLabel) return;
  const exists = state.spots.some((spot) => spot.label === state.selectedSpotLabel && !spot.isBlocked);
  if (!exists) setSelectedSpot("");
}

function dayOccupancyPercent(dayBookings) {
  const blockedKeys = new Set(state.spots.filter((s) => s.isBlocked).map((s) => normalizedSpotKey(s.label)));
  const usableCount = state.spots.filter((s) => !s.isBlocked).length;
  if (!usableCount) return 0;
  const bookedCount = new Set(
    dayBookings
      .map((b) => normalizedSpotKey(b.spot))
      .filter((key) => !blockedKeys.has(key))
  ).size;
  return Math.max(0, Math.min(100, Math.round((bookedCount / usableCount) * 100)));
}

function shouldKeepBookingLocally(booking) {
  const retentionCut = addDays(new Date(), -APP_RULES.bookingRetentionDays);
  return bookingEndDate(booking.bookingDate, booking.toTime) >= retentionCut;
}

function byId(id) {
  return document.getElementById(id);
}

function textRow(message) {
  const p = document.createElement("p");
  p.className = "muted";
  p.textContent = message;
  return p;
}

function toYmd(date) {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

function dayStart(dateYmd) {
  const [y, m, d] = dateYmd.split("-").map(Number);
  return new Date(y, m - 1, d, 0, 0, 0, 0);
}

function addDays(date, count) {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate() + count, date.getHours(), date.getMinutes(), date.getSeconds(), date.getMilliseconds());
}

function weekdayShort(date) {
  return new Intl.DateTimeFormat("en-US", { weekday: "short" }).format(date);
}

function formatShortDate(date) {
  return new Intl.DateTimeFormat("cs-CZ", { weekday: "short", day: "numeric", month: "short" }).format(date);
}

function formatLongDate(date) {
  return new Intl.DateTimeFormat("cs-CZ", { day: "2-digit", month: "2-digit", year: "numeric" }).format(date);
}

function firstName(value) {
  return String(value || "")
    .trim()
    .split(/\s+/)[0] || "there";
}

function bookingEndDate(date, toTime) {
  const [hour, minute] = String(toTime || "18:00")
    .split(":")
    .map((v) => Number(v));
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), Number.isFinite(hour) ? hour : 18, Number.isFinite(minute) ? minute : 0, 0, 0);
}

function parseBooking(id, data) {
  let bookingDate = new Date();
  const raw = data.bookingDate;
  if (raw?.toDate) bookingDate = raw.toDate();
  else if (typeof raw === "string") bookingDate = parseBookingDateString(raw);
  else if (typeof raw === "number") bookingDate = new Date(raw);

  if (!(bookingDate instanceof Date) || Number.isNaN(bookingDate.getTime())) return null;

  const spot = String(data.spot ?? data.spotLabel ?? data.spotId ?? "");
  if (!spot) return null;

  const email = String(data.email ?? data.userEmail ?? data.bookedForEmail ?? data.ownerEmail ?? "")
    .trim()
    .toLowerCase();
  const bookedForUid = String(data.bookedForUid ?? data.userUid ?? data.uid ?? data.userId ?? data.ownerUid ?? "").trim();
  const fromTime = String(data.fromTime ?? data.from ?? data.timeFrom ?? "07:00");
  const toTime = String(data.toTime ?? data.to ?? data.timeTo ?? "18:00");
  const user = String(data.user ?? data.displayName ?? "");
  const createdBy = String(data.createdBy ?? data.adminEmail ?? "")
    .trim()
    .toLowerCase();

  return { id, spot, bookingDate, email, bookedForUid, fromTime, toTime, user, createdBy };
}

function parseBookingDateString(value) {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return dayStart(value);
  }
  return new Date(value);
}

function isBookingForCurrentUser(booking) {
  const currentUid = String(state.user?.uid || "").trim();
  const currentEmail = String(state.user?.email || "")
    .trim()
    .toLowerCase();
  const bookingEmail = String(booking.email || "")
    .trim()
    .toLowerCase();
  const creatorEmail = String(booking.createdBy || "")
    .trim()
    .toLowerCase();
  const bookingUid = String(booking.bookedForUid || "").trim();

  if (currentUid && bookingUid && currentUid === bookingUid) return true;
  if (currentEmail && bookingEmail && currentEmail === bookingEmail) return true;
  if (currentEmail && !bookingEmail && creatorEmail && currentEmail === creatorEmail) return true;
  return false;
}

function parseSpot(id, data) {
  return {
    id: String(data.id ?? id),
    label: String(data.label ?? `Parking ${id}`),
    isAccessible: Boolean(data.isAccessible),
    isBlocked: Boolean(data.isBlocked),
    sortOrder: Number(data.sortOrder ?? 999),
  };
}

function parseAnnouncement(id, data) {
  const createdAtRaw = data.createdAt;
  let createdAtMs = 0;
  if (createdAtRaw?.toDate) createdAtMs = createdAtRaw.toDate().getTime();
  else if (typeof createdAtRaw === "string" || typeof createdAtRaw === "number") {
    const parsed = new Date(createdAtRaw);
    if (!Number.isNaN(parsed.getTime())) createdAtMs = parsed.getTime();
  }
  return {
    id,
    title: String(data.title ?? ""),
    body: String(data.body ?? ""),
    emoji: String(data.emoji ?? "📣"),
    isActive: Boolean(data.isActive),
    isPinned: Boolean(data.isPinned),
    imageURL: String(data.imageURL ?? data.imageUrl ?? data.image ?? "").trim(),
    createdAtMs,
  };
}

function parseUser(data) {
  return {
    uid: String(data.uid ?? ""),
    email: String(data.email ?? "").toLowerCase(),
    displayName: String(data.displayName ?? ""),
    role: String(data.role ?? "user"),
    status: String(data.status ?? "pending"),
    registrationPlate: String(data.registrationPlate ?? ""),
    carDescription: String(data.carDescription ?? ""),
    preferredVocative: String(data.preferredVocative ?? ""),
  };
}

function extractSpotNumber(spotLabel) {
  const key = normalizedSpotKey(spotLabel);
  return key || String(spotLabel || "");
}

function normalizedSpotKey(value) {
  const trimmed = String(value || "").trim();
  const match = trimmed.match(/\d+/);
  return match?.[0] || trimmed.toLowerCase();
}

function timesOverlap(aFrom, aTo, bFrom, bTo) {
  return toMinutes(aFrom) < toMinutes(bTo) && toMinutes(aTo) > toMinutes(bFrom);
}

function toMinutes(clock) {
  const [h, m] = String(clock || "00:00")
    .split(":")
    .map(Number);
  return (Number.isFinite(h) ? h : 0) * 60 + (Number.isFinite(m) ? m : 0);
}

function compareNumberString(a, b) {
  const na = Number(a);
  const nb = Number(b);
  if (Number.isFinite(na) && Number.isFinite(nb)) return na - nb;
  return String(a).localeCompare(String(b));
}

function friendlyAuthError(err) {
  const code = err?.code || "";
  if (code.includes("invalid-credential")) return "Invalid email or password.";
  if (code.includes("too-many-requests")) return "Too many attempts, try again shortly.";
  if (code.includes("network-request-failed")) return "Network error. Check connection.";
  return "Sign in failed.";
}
