import { initializeApp } from "https://www.gstatic.com/firebasejs/11.7.1/firebase-app.js";
import {
  getAuth,
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
  setPersistence,
  browserSessionPersistence,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-auth.js";
import {
  getFirestore,
  collection,
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  getDocs,
  serverTimestamp,
  Timestamp,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-firestore.js";
import { firebaseConfig } from "./firebase-config.js";

const state = {
  user: null,
  profile: null,
  selectedDate: toYmd(new Date()),
  spots: [],
  dayBookings: [],
  myBookings: [],
  announcements: [],
  listeners: {
    myBookings: null,
    dayBookings: null,
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
  freeCount: byId("freeCount"),
  bookedCount: byId("bookedCount"),
  blockedCount: byId("blockedCount"),
  spotsGrid: byId("spotsGrid"),
  bookForm: byId("bookForm"),
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
  // Never let startup fail silently; keep form from hard-refresh fallback.
  ui.loginForm.addEventListener("submit", (event) => event.preventDefault(), { capture: true });
  try {
    const app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    db = getFirestore(app);
    try {
      await setPersistence(auth, browserSessionPersistence);
    } catch (persistError) {
      // Continue with default persistence if browser/session storage is restricted.
      console.warn("setPersistence failed, continuing with default:", persistError);
    }
    bootstrap();
  } catch (error) {
    console.error("Web app bootstrap failed:", error);
    ui.authError.textContent =
      "Initialization failed. Open browser console and send me the first red error line.";
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
    subscribeDayBookings();
  });

  ui.bookForm.addEventListener("submit", onBookSubmit);
  ui.profileForm.addEventListener("submit", onSaveProfile);
  ui.tabs.forEach((tab) => tab.addEventListener("click", () => switchTab(tab.dataset.tab)));
}

async function handleAuthState(user) {
  clearAllListeners();
  state.user = user;
  state.profile = null;

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
  if (role !== "admin" && role !== "privileged") {
    if (currentTab() === "admin") switchTab("home");
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
  subscribeDayBookings();
  subscribeMyBookings();
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
      renderParking();
    },
    () => {
      state.spots = [];
      renderSpotSelect();
      renderParking();
    }
  );
}

function subscribeDayBookings() {
  state.listeners.dayBookings?.();
  const from = dayStart(state.selectedDate);
  const to = dayEndExclusive(state.selectedDate);
  const q = query(
    collection(db, "bookings"),
    where("bookingDate", ">=", Timestamp.fromDate(from)),
    where("bookingDate", "<", Timestamp.fromDate(to)),
    orderBy("bookingDate", "asc")
  );
  state.listeners.dayBookings = onSnapshot(
    q,
    (snap) => {
      state.dayBookings = snap.docs.map((d) => parseBooking(d.id, d.data())).filter(Boolean);
      renderParking();
    },
    () => {
      state.dayBookings = [];
      renderParking();
    }
  );
}

function subscribeMyBookings() {
  state.listeners.myBookings?.();
  if (!state.user) return;
  const email = state.user.email?.toLowerCase() || "";
  const q = query(
    collection(db, "bookings"),
    where("email", "==", email),
    orderBy("bookingDate", "asc"),
    limit(200)
  );
  state.listeners.myBookings = onSnapshot(
    q,
    (snap) => {
      state.myBookings = snap.docs.map((d) => parseBooking(d.id, d.data())).filter(Boolean);
      renderHomeHero();
      renderMyBookings();
    },
    () => {
      state.myBookings = [];
      renderHomeHero();
      renderMyBookings();
    }
  );
}

function subscribeAnnouncements() {
  state.listeners.announcements?.();
  const q = query(
    collection(db, "announcements"),
    where("isActive", "==", true),
    orderBy("createdAt", "desc"),
    limit(12)
  );
  state.listeners.announcements = onSnapshot(
    q,
    (snap) => {
      state.announcements = snap.docs.map((d) => parseAnnouncement(d.id, d.data())).filter(Boolean);
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

function renderGreeting() {
  const name = (state.profile?.preferredVocative || "").trim() || firstName(state.profile?.displayName || state.user?.email || "there");
  ui.greetingText.textContent = `Hello, ${name}`;
}

function renderHomeHero() {
  const now = new Date();
  const upcoming = state.myBookings
    .slice()
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime())
    .find((b) => b.bookingDate >= dayStart(toYmd(now)));
  if (!upcoming) {
    ui.heroState.textContent = "NO BOOKING";
    ui.heroDate.textContent = "";
    ui.heroSpot.textContent = "--";
    ui.heroTime.textContent = "Book your next place";
    return;
  }
  const isToday = toYmd(upcoming.bookingDate) === toYmd(now);
  ui.heroState.textContent = isToday ? "ACTIVE" : "UPCOMING";
  ui.heroDate.textContent = `${isToday ? "Today" : "Tomorrow"} · ${formatShortDate(upcoming.bookingDate)}`;
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
    const h = document.createElement("h4");
    h.textContent = `${item.emoji || "📣"} ${item.title}`;
    const p = document.createElement("p");
    p.textContent = item.body || "";
    wrap.append(h, p);
    ui.announcementsList.append(wrap);
  }
}

function renderSpotSelect() {
  ui.spotSelect.textContent = "";
  const available = state.spots.filter((s) => !s.isBlocked);
  for (const spot of available) {
    const option = document.createElement("option");
    option.value = spot.label;
    option.textContent = spot.label;
    ui.spotSelect.append(option);
  }
}

function renderParking() {
  const blocked = new Set(state.spots.filter((s) => s.isBlocked).map((s) => s.label));
  const booked = new Set(state.dayBookings.map((b) => b.spot));
  const usable = state.spots.filter((s) => !s.isBlocked);

  ui.freeCount.textContent = String(Math.max(usable.length - booked.size, 0));
  ui.bookedCount.textContent = String(booked.size);
  ui.blockedCount.textContent = String(blocked.size);

  ui.spotsGrid.textContent = "";
  for (const spot of state.spots) {
    const cell = document.createElement("article");
    cell.className = "spot-cell";
    let stateName = "free";
    if (spot.isBlocked) stateName = "blocked";
    else if (booked.has(spot.label)) stateName = "booked";
    cell.dataset.state = stateName;

    const strong = document.createElement("strong");
    strong.textContent = String(extractSpotNumber(spot.label));
    const small = document.createElement("small");
    small.textContent = stateName.toUpperCase();
    cell.append(strong, small);
    ui.spotsGrid.append(cell);
  }
}

function renderMyBookings() {
  ui.myBookingsList.textContent = "";
  const upcoming = state.myBookings
    .slice()
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime())
    .filter((b) => b.bookingDate >= dayStart(toYmd(new Date())));
  if (!upcoming.length) {
    ui.myBookingsList.append(textRow("No upcoming bookings."));
    renderHomeHero();
    return;
  }
  for (const booking of upcoming) {
    const node = ui.bookingTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".title").textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(booking.bookingDate)}`;
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

  const spot = ui.spotSelect.value;
  const dateYmd = ui.bookDate.value;
  const fromTime = ui.bookFrom.value;
  const toTime = ui.bookTo.value;

  if (!spot || !dateYmd || !fromTime || !toTime || fromTime >= toTime) {
    ui.bookError.textContent = "Check date and time range.";
    return;
  }

  ui.bookButton.disabled = true;
  try {
    const date = dayStart(dateYmd);
    await ensureSpotFreeForRange(spot, date, fromTime, toTime);

    const bookingRef = doc(collection(db, "bookings"));
    const email = state.user.email.toLowerCase();
    await setDoc(bookingRef, {
      id: bookingRef.id,
      title: `Reservation for ${state.profile.displayName || email}`,
      spot,
      user: state.profile.displayName || email,
      email,
      fromTime,
      toTime,
      createdBy: email,
      bookingDate: Timestamp.fromDate(date),
      createdAt: serverTimestamp(),
    });
  } catch (err) {
    ui.bookError.textContent = err?.message || "Could not create booking.";
  } finally {
    ui.bookButton.disabled = false;
  }
}

async function cancelBooking(booking) {
  if (!state.user || !state.profile) return;
  const ok = window.confirm(`Cancel booking for spot ${extractSpotNumber(booking.spot)} on ${formatLongDate(booking.bookingDate)}?`);
  if (!ok) return;

  try {
    const email = state.user.email.toLowerCase();
    const role = (state.profile.role || "").toLowerCase();
    if (email !== booking.email.toLowerCase() && role !== "admin") {
      throw new Error("You can cancel only your own bookings.");
    }
    await deleteDoc(doc(db, "bookings", booking.id));
  } catch (err) {
    alert(err?.message || "Cancel failed.");
  }
}

async function ensureSpotFreeForRange(spot, bookingDate, fromTime, toTime) {
  const from = dayStart(toYmd(bookingDate));
  const to = dayEndExclusive(toYmd(bookingDate));
  const q = query(
    collection(db, "bookings"),
    where("spot", "==", spot),
    where("bookingDate", ">=", Timestamp.fromDate(from)),
    where("bookingDate", "<", Timestamp.fromDate(to))
  );
  const snap = await getDocs(q);
  const conflicts = snap.docs
    .map((d) => parseBooking(d.id, d.data()))
    .filter(Boolean)
    .some((b) => timesOverlap(fromTime, toTime, b.fromTime, b.toTime));
  if (conflicts) {
    throw new Error("This spot is already booked in that time range.");
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
  } catch (err) {
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

function dayEndExclusive(dateYmd) {
  const start = dayStart(dateYmd);
  return new Date(start.getFullYear(), start.getMonth(), start.getDate() + 1, 0, 0, 0, 0);
}

function formatShortDate(date) {
  return new Intl.DateTimeFormat("cs-CZ", { weekday: "short", day: "numeric", month: "short" }).format(date);
}

function formatLongDate(date) {
  return new Intl.DateTimeFormat("cs-CZ", { day: "2-digit", month: "2-digit", year: "numeric" }).format(date);
}

function firstName(value) {
  return String(value || "").trim().split(/\s+/)[0] || "there";
}

function parseBooking(id, data) {
  const bookingDateRaw = data.bookingDate;
  let bookingDate = new Date();
  if (bookingDateRaw?.toDate) bookingDate = bookingDateRaw.toDate();
  else if (typeof bookingDateRaw === "string" || typeof bookingDateRaw === "number") bookingDate = new Date(bookingDateRaw);

  const spot = String(data.spot ?? data.spotLabel ?? "");
  const email = String(data.email ?? data.userEmail ?? "").toLowerCase();
  const fromTime = String(data.fromTime ?? data.from ?? data.timeFrom ?? "07:00");
  const toTime = String(data.toTime ?? data.to ?? data.timeTo ?? "18:00");
  const user = String(data.user ?? data.displayName ?? "");
  const createdBy = String(data.createdBy ?? data.adminEmail ?? "").toLowerCase();
  if (!spot || !email) return null;
  return { id, spot, bookingDate, email, fromTime, toTime, user, createdBy };
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
  return {
    id,
    title: String(data.title ?? ""),
    body: String(data.body ?? ""),
    emoji: String(data.emoji ?? "📣"),
    isPinned: Boolean(data.isPinned),
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
  const clean = String(spotLabel || "");
  const fromParking = clean.replace(/^Parking\s+/i, "").trim();
  return fromParking || clean;
}

function timesOverlap(aFrom, aTo, bFrom, bTo) {
  return aFrom < bTo && bFrom < aTo;
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
