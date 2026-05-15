import { initializeApp } from "https://www.gstatic.com/firebasejs/11.7.1/firebase-app.js";
import {
  browserLocalPersistence,
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
  getDocsFromServer,
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
  selectedAdminSpotLabel: "",
  editingBooking: null,
  spots: [],
  allBookings: [],
  dayBookings: [],
  myBookings: [],
  announcements: [],
  lastBookedSummary: null,
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
  rememberMeInput: byId("rememberMeInput"),
  pendingSignOut: byId("pendingSignOut"),
  signOutButton: byId("signOutButton"),
  greetingText: byId("greetingText"),
  heroState: byId("heroState"),
  heroDate: byId("heroDate"),
  heroSpot: byId("heroSpot"),
  heroTime: byId("heroTime"),
  announcementsList: byId("announcementsList"),
  refreshHome: byId("refreshHome"),
  dayPills: byId("dayPills"),
  freeCount: byId("freeCount"),
  bookedCount: byId("bookedCount"),
  blockedCount: byId("blockedCount"),
  spotsGrid: byId("spotsGrid"),
  adminSpotInspector: byId("adminSpotInspector"),
  adminSpotInspectorTitle: byId("adminSpotInspectorTitle"),
  adminSpotInspectorList: byId("adminSpotInspectorList"),
  adminSpotInspectorClose: byId("adminSpotInspectorClose"),
  bookForm: byId("bookForm"),
  selectedSpotDisplay: byId("selectedSpotDisplay"),
  selectedSpotHint: byId("selectedSpotHint"),
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
  bookingSuccessModal: byId("bookingSuccessModal"),
  bookingSuccessMessage: byId("bookingSuccessMessage"),
  bookingSuccessStay: byId("bookingSuccessStay"),
  bookingSuccessCalendar: byId("bookingSuccessCalendar"),
  bookingSuccessGo: byId("bookingSuccessGo"),
  bookingEditModal: byId("bookingEditModal"),
  bookingEditForm: byId("bookingEditForm"),
  bookingEditSpot: byId("bookingEditSpot"),
  bookingEditDate: byId("bookingEditDate"),
  bookingEditFrom: byId("bookingEditFrom"),
  bookingEditTo: byId("bookingEditTo"),
  bookingEditError: byId("bookingEditError"),
  bookingEditSave: byId("bookingEditSave"),
  bookingEditCancel: byId("bookingEditCancel"),
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

const REQUIRED_FIREBASE_KEYS = [
  "apiKey",
  "authDomain",
  "projectId",
  "storageBucket",
  "messagingSenderId",
  "appId",
];

const LOGIN_PERSISTENCE_KEY = "el_parking_keep_signed_in";

function validateFirebaseConfig(config) {
  if (!config || typeof config !== "object") return "Firebase config is missing.";
  for (const key of REQUIRED_FIREBASE_KEYS) {
    const value = String(config[key] ?? "").trim();
    if (!value) return `Firebase config missing key: ${key}`;
    if (value.includes("REPLACE_ME") || value.includes("TVUJ_NOVY_KEY")) {
      return `Firebase config has placeholder value in key: ${key}`;
    }
  }
  return "";
}

function shouldKeepSignedIn() {
  try {
    const saved = window.localStorage.getItem(LOGIN_PERSISTENCE_KEY);
    if (saved === null) return true;
    return saved === "1";
  } catch {
    return true;
  }
}

function saveKeepSignedInPreference(value) {
  try {
    window.localStorage.setItem(LOGIN_PERSISTENCE_KEY, value ? "1" : "0");
  } catch {
    // ignore storage failures
  }
}

function currentAuthPersistence() {
  return shouldKeepSignedIn() ? browserLocalPersistence : browserSessionPersistence;
}

async function boot() {
  ui.loginForm.addEventListener("submit", (event) => event.preventDefault(), { capture: true });
  try {
    const configError = validateFirebaseConfig(firebaseConfig);
    if (configError) throw new Error(configError);

    const app = initializeApp(firebaseConfig);
    auth = getAuth(app);
    db = getFirestore(app);
    try {
      await setPersistence(auth, currentAuthPersistence());
    } catch (persistError) {
      console.warn("setPersistence failed, fallback to default:", persistError);
    }
    bootstrap();
  } catch (error) {
    console.error("Web bootstrap failed:", error);
    const reason = error?.message || String(error || "Unknown initialization error");
    ui.authError.textContent = `Initialization failed: ${reason}`;
    ui.loginButton.disabled = true;
  }
}

function bootstrap() {
  if (ui.bookDate) ui.bookDate.value = state.selectedDate;
  if (ui.rememberMeInput) ui.rememberMeInput.checked = shouldKeepSignedIn();
  bindEvents();
  syncBookUiState();
  onAuthStateChanged(auth, handleAuthState);
}

function bindEvents() {
  ui.loginForm?.addEventListener("submit", onLoginSubmit);
  ui.signOutButton?.addEventListener("click", () => signOut(auth));
  ui.pendingSignOut?.addEventListener("click", () => signOut(auth));
  ui.refreshHome?.addEventListener("click", () => renderAnnouncements());
  ui.refreshBookings?.addEventListener("click", () => renderMyBookings());
  ui.rememberMeInput?.addEventListener("change", async () => {
    saveKeepSignedInPreference(Boolean(ui.rememberMeInput.checked));
    try {
      await setPersistence(auth, currentAuthPersistence());
    } catch (error) {
      console.warn("Could not update auth persistence:", error);
    }
  });

  ui.bookDate?.addEventListener("change", () => {
    state.selectedDate = ui.bookDate.value || state.selectedDate;
    state.selectedAdminSpotLabel = "";
    recalculateDerivedBookings();
    renderParking();
    renderDayPills();
  });

  ui.spotSelect?.addEventListener("change", () => {
    if (!ui.spotSelect.value) return;
    setSelectedSpot(ui.spotSelect.value);
    renderParking();
    syncBookUiState();
  });

  ui.bookForm?.addEventListener("submit", onBookSubmit);
  ui.profileForm?.addEventListener("submit", onSaveProfile);
  ui.bookFrom?.addEventListener("change", syncBookUiState);
  ui.bookTo?.addEventListener("change", syncBookUiState);
  ui.adminSpotInspectorClose?.addEventListener("click", closeAdminSpotInspector);
  ui.bookingSuccessStay?.addEventListener("click", hideBookingSuccessModal);
  ui.bookingSuccessCalendar?.addEventListener("click", () => {
    if (!state.lastBookedSummary) return;
    downloadCalendarForBooking(state.lastBookedSummary);
  });
  ui.bookingSuccessGo?.addEventListener("click", () => {
    hideBookingSuccessModal();
    switchTab("bookings");
    renderMyBookings();
  });
  ui.bookingSuccessModal?.addEventListener("click", (event) => {
    if (event.target === ui.bookingSuccessModal) hideBookingSuccessModal();
  });
  ui.bookingEditCancel?.addEventListener("click", closeBookingEditModal);
  ui.bookingEditForm?.addEventListener("submit", onSaveBookingEdit);
  ui.bookingEditModal?.addEventListener("click", (event) => {
    if (event.target === ui.bookingEditModal) closeBookingEditModal();
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      hideBookingSuccessModal();
      closeBookingEditModal();
    }
  });
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
  state.lastBookedSummary = null;
  state.selectedSpotLabel = "";
  state.selectedAdminSpotLabel = "";
  state.editingBooking = null;

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
    saveKeepSignedInPreference(Boolean(ui.rememberMeInput?.checked));
    await setPersistence(auth, currentAuthPersistence());
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
      ensureSelectedSpotIsValid();
      renderHomeHero();
      renderMyBookings();
      renderParking();
      renderAdminSpotInspector();
      renderDayPills();
    },
    () => {
      state.allBookings = [];
      recalculateDerivedBookings();
      ensureSelectedSpotIsValid();
      renderHomeHero();
      renderMyBookings();
      renderParking();
      renderAdminSpotInspector();
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

function isAdminLike() {
  const role = (state.profile?.role || "").toLowerCase();
  return role === "admin" || role === "privileged";
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

  if (!state.selectedSpotLabel) {
    ui.spotSelect.value = "";
  }
}

function bookingsForSpotOnSelectedDay(spotLabel) {
  const key = normalizedSpotKey(spotLabel);
  return state.dayBookings
    .filter((booking) => normalizedSpotKey(booking.spot) === key)
    .slice()
    .sort((a, b) => toMinutes(a.fromTime) - toMinutes(b.fromTime));
}

function bookingDisplayName(booking) {
  return String(booking.user || booking.email || "Unknown user").trim();
}

function renderParking() {
  const adminLike = isAdminLike();
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
  const hintText = adminLike
    ? "Tap FREE to select for booking, or BOOKED to inspect who holds the spot."
    : "Tap a FREE spot tile to select it.";
  const hintNode = document.querySelector(".spot-grid-hint");
  if (hintNode) hintNode.textContent = hintText;

  ui.spotsGrid.textContent = "";
  for (const spot of state.spots) {
    const key = normalizedSpotKey(spot.label);
    let stateName = "free";
    if (spot.isBlocked) stateName = "blocked";
    else if (bookedKeys.has(key)) stateName = "booked";
    const isSelectedFree = normalizedSpotKey(state.selectedSpotLabel) === key && stateName === "free";
    const isSelectedBooked = normalizedSpotKey(state.selectedAdminSpotLabel) === key && stateName === "booked";
    const spotBookings = stateName === "booked" ? bookingsForSpotOnSelectedDay(spot.label) : [];
    const leadBooking = spotBookings[0];

    const cell = document.createElement("button");
    cell.type = "button";
    cell.className = "spot-cell";
    cell.dataset.state = stateName;
    cell.classList.toggle("selected", isSelectedFree || isSelectedBooked);
    if (stateName === "booked" && adminLike) cell.classList.add("admin-clickable");
    cell.disabled = stateName !== "free" && !(stateName === "booked" && adminLike);

    const strong = document.createElement("strong");
    strong.textContent = String(extractSpotNumber(spot.label));
    const small = document.createElement("small");
    if (stateName === "booked" && adminLike && leadBooking) {
      small.textContent =
        spotBookings.length > 1
          ? `${spotBookings.length} BOOKINGS`
          : `BOOKED ${leadBooking.fromTime}-${leadBooking.toTime}`;
    } else {
      small.textContent = stateName === "free" ? "FREE" : stateName === "booked" ? "BOOKED" : "BLOCKED";
    }
    cell.append(strong, small);

    if (stateName === "booked" && adminLike && leadBooking) {
      const owner = document.createElement("div");
      owner.className = "spot-cell-booking-owner";
      owner.textContent = bookingDisplayName(leadBooking);
      cell.append(owner);
    }

    if (isSelectedFree) {
      const check = document.createElement("span");
      check.className = "spot-cell-check";
      check.textContent = "✓";
      cell.append(check);
    }

    if (stateName === "free") {
      cell.addEventListener("click", () => {
        setSelectedSpot(spot.label);
        renderParking();
        syncBookUiState();
        scrollBookingFormIntoView();
      });
    } else if (stateName === "booked" && adminLike) {
      cell.addEventListener("click", () => {
        state.selectedAdminSpotLabel = spot.label;
        setSelectedSpot("");
        renderParking();
        renderAdminSpotInspector();
      });
    }

    ui.spotsGrid.append(cell);
  }

  ui.selectedSpotDisplay.value = state.selectedSpotLabel ? `Spot ${extractSpotNumber(state.selectedSpotLabel)}` : "";
  syncBookUiState();
  renderAdminSpotInspector();
}

function renderMyBookings() {
  ui.myBookingsList.textContent = "";
  const adminLike = isAdminLike();
  const source = adminLike ? state.allBookings : state.myBookings;
  const upcoming = source
    .slice()
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime())
    .filter((b) => bookingEndDate(b.bookingDate, b.toTime) >= new Date());

  if (!upcoming.length) {
    ui.myBookingsList.append(textRow("No upcoming bookings."));
    renderHomeHero();
    return;
  }

  for (const booking of upcoming) {
    if (adminLike) {
      const row = document.createElement("article");
      row.className = "admin-booking-row";

      const main = document.createElement("div");
      main.className = "admin-booking-main";
      const title = document.createElement("p");
      title.className = "admin-booking-title";
      title.textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(booking.bookingDate)} · ${bookingDisplayName(
        booking
      )}`;
      const meta = document.createElement("p");
      meta.className = "admin-booking-meta";
      meta.textContent = `${booking.fromTime} - ${booking.toTime}${booking.email ? ` · ${booking.email}` : ""}`;
      main.append(title, meta);

      const actions = document.createElement("div");
      actions.className = "admin-booking-actions";
      const calendar = document.createElement("button");
      calendar.type = "button";
      calendar.className = "btn subtle small";
      calendar.textContent = "Calendar";
      calendar.addEventListener("click", () => downloadCalendarForBooking(booking));
      const edit = document.createElement("button");
      edit.type = "button";
      edit.className = "btn subtle small";
      edit.textContent = "Edit";
      edit.addEventListener("click", () => openBookingEditModal(booking));
      const cancel = document.createElement("button");
      cancel.type = "button";
      cancel.className = "btn danger small";
      cancel.textContent = "Cancel";
      cancel.addEventListener("click", () => cancelBooking(booking));
      actions.append(calendar, edit, cancel);

      row.append(main, actions);
      ui.myBookingsList.append(row);
      continue;
    }

    const node = ui.bookingTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".title").textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(booking.bookingDate)}`;
    node.querySelector(".meta").textContent = `${booking.fromTime} - ${booking.toTime}`;
    const calendarButton = node.querySelector(".calendar-btn");
    const cancel = node.querySelector(".cancel-btn");
    calendarButton?.addEventListener("click", () => downloadCalendarForBooking(booking));
    cancel?.addEventListener("click", () => cancelBooking(booking));
    ui.myBookingsList.append(node);
  }

  renderHomeHero();
}

function renderAdminSpotInspector() {
  if (!ui.adminSpotInspector) return;
  if (!isAdminLike() || !state.selectedAdminSpotLabel) {
    ui.adminSpotInspector.classList.add("hidden");
    return;
  }

  const bookings = bookingsForSpotOnSelectedDay(state.selectedAdminSpotLabel);
  if (!bookings.length) {
    ui.adminSpotInspector.classList.add("hidden");
    state.selectedAdminSpotLabel = "";
    return;
  }

  ui.adminSpotInspector.classList.remove("hidden");
  ui.adminSpotInspectorTitle.textContent = `Spot ${extractSpotNumber(state.selectedAdminSpotLabel)} · ${formatLongDate(dayStart(state.selectedDate))}`;
  ui.adminSpotInspectorList.textContent = "";

  for (const booking of bookings) {
    const row = document.createElement("article");
    row.className = "admin-booking-row";

    const main = document.createElement("div");
    main.className = "admin-booking-main";
    const title = document.createElement("p");
    title.className = "admin-booking-title";
    title.textContent = bookingDisplayName(booking);
    const meta = document.createElement("p");
    meta.className = "admin-booking-meta";
    meta.textContent = `${booking.fromTime} - ${booking.toTime}${booking.email ? ` · ${booking.email}` : ""}`;
    main.append(title, meta);

    const actions = document.createElement("div");
    actions.className = "admin-booking-actions";
    const calendar = document.createElement("button");
    calendar.type = "button";
    calendar.className = "btn subtle small";
    calendar.textContent = "Calendar";
    calendar.addEventListener("click", () => downloadCalendarForBooking(booking));
    const edit = document.createElement("button");
    edit.type = "button";
    edit.className = "btn subtle small";
    edit.textContent = "Edit";
    edit.addEventListener("click", () => openBookingEditModal(booking));

    const cancel = document.createElement("button");
    cancel.type = "button";
    cancel.className = "btn danger small";
    cancel.textContent = "Cancel";
    cancel.addEventListener("click", () => cancelBooking(booking));

    actions.append(calendar, edit, cancel);
    row.append(main, actions);
    ui.adminSpotInspectorList.append(row);
  }
}

function closeAdminSpotInspector() {
  state.selectedAdminSpotLabel = "";
  ui.adminSpotInspector?.classList.add("hidden");
}

function openBookingEditModal(booking) {
  if (!booking || !ui.bookingEditModal) return;
  state.editingBooking = booking;
  ui.bookingEditError.textContent = "";

  const availableSpots = state.spots.filter((spot) => !spot.isBlocked).map((spot) => spot.label);
  const hasCurrent = availableSpots.some((label) => normalizedSpotKey(label) === normalizedSpotKey(booking.spot));
  if (!hasCurrent) availableSpots.unshift(booking.spot);

  ui.bookingEditSpot.textContent = "";
  for (const label of availableSpots) {
    const option = document.createElement("option");
    option.value = label;
    option.textContent = label;
    ui.bookingEditSpot.append(option);
  }

  ui.bookingEditSpot.value = booking.spot;
  ui.bookingEditDate.value = toYmd(booking.bookingDate);
  ui.bookingEditFrom.value = booking.fromTime;
  ui.bookingEditTo.value = booking.toTime;
  ui.bookingEditModal.classList.remove("hidden");
  ui.bookingEditModal.setAttribute("aria-hidden", "false");
}

function closeBookingEditModal() {
  state.editingBooking = null;
  if (!ui.bookingEditModal) return;
  ui.bookingEditModal.classList.add("hidden");
  ui.bookingEditModal.setAttribute("aria-hidden", "true");
}

async function onSaveBookingEdit(event) {
  event.preventDefault();
  if (!state.editingBooking) return;
  if (!isAdminLike()) {
    ui.bookingEditError.textContent = "Only admin can edit bookings.";
    return;
  }

  const booking = state.editingBooking;
  const nextSpot = String(ui.bookingEditSpot.value || "").trim();
  const nextDateYmd = String(ui.bookingEditDate.value || "").trim();
  const nextFrom = String(ui.bookingEditFrom.value || "").trim();
  const nextTo = String(ui.bookingEditTo.value || "").trim();

  if (!nextSpot || !nextDateYmd || !nextFrom || !nextTo || nextFrom >= nextTo) {
    ui.bookingEditError.textContent = "Check date and time range.";
    return;
  }

  const isBlocked = state.spots.some(
    (spot) => spot.isBlocked && normalizedSpotKey(spot.label) === normalizedSpotKey(nextSpot)
  );
  if (isBlocked) {
    ui.bookingEditError.textContent = "Selected spot is blocked.";
    return;
  }

  ui.bookingEditSave.disabled = true;
  ui.bookingEditError.textContent = "";
  try {
    await updateBookingTransaction(booking, {
      spot: nextSpot,
      dateYmd: nextDateYmd,
      fromTime: nextFrom,
      toTime: nextTo,
    });
    closeBookingEditModal();
  } catch (err) {
    ui.bookingEditError.textContent = err?.message || "Booking update failed.";
  } finally {
    ui.bookingEditSave.disabled = false;
  }
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
    state.lastBookedSummary = {
      id: `new-${dateYmd}-${extractSpotNumber(spot)}`,
      spot,
      bookingDate: date,
      fromTime,
      toTime,
    };
    ui.bookError.textContent = "";
    showBookingSuccessModal(spot, date, fromTime, toTime);
  } catch (err) {
    const message = err?.message || "Could not create booking.";
    const isConflict = message.toLowerCase().includes("already booked");
    if (isConflict) {
      ui.bookError.textContent = "Spot was booked meanwhile. Refreshing availability...";
      try {
        await refreshBookingsFromServer();
      } catch (_) {
        // keep original message below
      }
      ui.bookError.textContent = message;
    } else {
      ui.bookError.textContent = message;
    }
  } finally {
    syncBookUiState();
  }
}

function enforceBookingRules(spotLabel, dateYmd, fromTime, toTime) {
  if (fromTime >= toTime) throw new Error("Invalid time range.");
  const adminLike = isAdminLike();

  const blocked = state.spots.some(
    (spot) => spot.isBlocked && normalizedSpotKey(spot.label) === normalizedSpotKey(spotLabel)
  );
  if (blocked) throw new Error("This spot is blocked.");

  if (!adminLike) {
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
    const lockState = await loadLiveLockSlots(transaction, lockRef, spotLabel, dateYmd);
    const slots = lockState.slots;

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

async function refreshBookingsFromServer() {
  if (!db) return;
  const snap = await getDocsFromServer(collection(db, "bookings"));
  const loaded = snap.docs
    .map((d) => parseBooking(d.id, d.data()))
    .filter(Boolean)
    .filter(shouldKeepBookingLocally)
    .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime());
  state.allBookings = loaded;
  recalculateDerivedBookings();
  ensureSelectedSpotIsValid();
  renderHomeHero();
  renderMyBookings();
  renderParking();
  renderAdminSpotInspector();
  renderDayPills();
}

async function updateBookingTransaction(existingBooking, next) {
  if (!existingBooking?.id) throw new Error("Booking is missing id.");

  const nextDate = dayStart(next.dateYmd);
  const bookingRef = doc(db, "bookings", existingBooking.id);
  const oldDayKey = toYmd(existingBooking.bookingDate);
  const newDayKey = next.dateYmd;
  const oldLockRef = doc(db, "spot_locks", `${existingBooking.spot}_${oldDayKey}`);
  const newLockRef = doc(db, "spot_locks", `${next.spot}_${newDayKey}`);

  await runTransaction(db, async (transaction) => {
    const bookingSnap = await transaction.get(bookingRef);

    if (!bookingSnap.exists()) throw new Error("Booking no longer exists.");

    const oldLockState = await loadLiveLockSlots(
      transaction,
      oldLockRef,
      existingBooking.spot,
      oldDayKey
    );
    const newLockState = await loadLiveLockSlots(transaction, newLockRef, next.spot, newDayKey);

    const newSlots = newLockState.slots;
    const overlap = newSlots
      .filter((slot) => String(slot.bookingId || "") !== existingBooking.id)
      .some((slot) =>
        timesOverlap(
          next.fromTime,
          next.toTime,
          String(slot.from || "00:00"),
          String(slot.to || "00:00")
        )
      );
    if (overlap) throw new Error("This spot is already booked in that time range.");

    const oldSlotsWithoutCurrent = oldLockState.slots.filter(
      (slot) => String(slot.bookingId || "") !== existingBooking.id
    );
    transaction.set(oldLockRef, { slots: oldSlotsWithoutCurrent }, { merge: true });

    const newSlotsWithoutCurrent = newSlots.filter(
      (slot) => String(slot.bookingId || "") !== existingBooking.id
    );
    transaction.set(
      newLockRef,
      {
        slots: [...newSlotsWithoutCurrent, { from: next.fromTime, to: next.toTime, bookingId: existingBooking.id }],
      },
      { merge: true }
    );

    const spotDoc = state.spots.find((spot) => normalizedSpotKey(spot.label) === normalizedSpotKey(next.spot));
    const expiresAt = addDays(bookingEndDate(nextDate, next.toTime), APP_RULES.bookingRetentionDays);

    transaction.update(bookingRef, {
      spot: next.spot,
      spotID: spotDoc?.id || extractSpotNumber(next.spot),
      fromTime: next.fromTime,
      toTime: next.toTime,
      bookingDate: Timestamp.fromDate(nextDate),
      expiresAt: Timestamp.fromDate(expiresAt),
      updatedAt: serverTimestamp(),
    });
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
    const ownerEmail = String(booking.email || "").trim().toLowerCase();
    if (myEmail !== ownerEmail && !isAdminLike()) {
      throw new Error("You can cancel only your own bookings.");
    }

    const bookingDateKey = toYmd(booking.bookingDate);
    const lockRef = doc(db, "spot_locks", `${booking.spot}_${bookingDateKey}`);
    const bookingRef = doc(db, "bookings", booking.id);

    await runTransaction(db, async (transaction) => {
      const lockState = await loadLiveLockSlots(transaction, lockRef, booking.spot, bookingDateKey);
      const updated = lockState.slots.filter((slot) => String(slot.bookingId || "") !== booking.id);
      transaction.set(lockRef, { slots: updated }, { merge: true });
      transaction.delete(bookingRef);
    });
  } catch (err) {
    alert(err?.message || "Cancel failed.");
  }
}

async function loadLiveLockSlots(transaction, lockRef, spotLabel, dateYmd) {
  const lockSnap = await transaction.get(lockRef);
  const rawSlots = lockSnap.data()?.slots ?? [];
  const normalizedRequestedSpot = normalizedSpotKey(spotLabel);
  const liveSlots = [];

  for (const raw of rawSlots) {
    const bookingId = String(raw?.bookingId || "").trim();
    if (!bookingId) continue;

    const from = String(raw?.from || "").trim();
    const to = String(raw?.to || "").trim();
    if (!from || !to) continue;

    const bookingRef = doc(db, "bookings", bookingId);
    const bookingSnap = await transaction.get(bookingRef);
    if (!bookingSnap.exists()) continue;

    const parsed = parseBooking(bookingId, bookingSnap.data());
    if (!parsed) continue;

    const sameDay = toYmd(parsed.bookingDate) === dateYmd;
    const sameSpot = normalizedSpotKey(parsed.spot) === normalizedRequestedSpot;
    if (!sameDay || !sameSpot) continue;

    liveSlots.push({ from: parsed.fromTime, to: parsed.toTime, bookingId });
  }

  return { slots: liveSlots };
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
  if (tab !== "parking") closeAdminSpotInspector();
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
  ui.selectedSpotDisplay.value = label ? `Spot ${extractSpotNumber(label)}` : "";
}

function syncBookUiState() {
  const hasSelectedSpot = Boolean(state.selectedSpotLabel);
  const hasValidTimes = Boolean(ui.bookFrom.value && ui.bookTo.value && ui.bookFrom.value < ui.bookTo.value);
  ui.bookButton.disabled = !(hasSelectedSpot && hasValidTimes);

  if (!hasSelectedSpot) {
    ui.selectedSpotHint.textContent = "No spot selected yet.";
    ui.selectedSpotHint.classList.remove("ok");
    return;
  }

  if (!hasValidTimes) {
    ui.selectedSpotHint.textContent = "Selected, now fix time range.";
    ui.selectedSpotHint.classList.remove("ok");
    return;
  }

  ui.selectedSpotHint.textContent = `Selected: Spot ${extractSpotNumber(state.selectedSpotLabel)}. Ready to confirm.`;
  ui.selectedSpotHint.classList.add("ok");
}

function showBookingSuccessModal(spotLabel, bookingDate, fromTime, toTime) {
  if (!ui.bookingSuccessModal || !ui.bookingSuccessMessage) return;
  const spot = extractSpotNumber(spotLabel);
  const dateText = formatLongDate(bookingDate);
  ui.bookingSuccessMessage.textContent = `Spot ${spot} booked for ${dateText}, ${fromTime}-${toTime}.`;
  ui.bookingSuccessModal.classList.remove("hidden");
  ui.bookingSuccessModal.setAttribute("aria-hidden", "false");
}

function hideBookingSuccessModal() {
  if (!ui.bookingSuccessModal) return;
  ui.bookingSuccessModal.classList.add("hidden");
  ui.bookingSuccessModal.setAttribute("aria-hidden", "true");
}

function scrollBookingFormIntoView() {
  if (!ui.bookForm) return;
  const rect = ui.bookForm.getBoundingClientRect();
  const viewportHeight = window.innerHeight || document.documentElement.clientHeight;
  const alreadyVisible = rect.top >= 0 && rect.top <= viewportHeight * 0.6;
  if (alreadyVisible) return;
  ui.bookForm.scrollIntoView({ behavior: "smooth", block: "start" });
}

function ensureSelectedSpotIsValid() {
  if (!state.selectedSpotLabel) return;
  const exists = state.spots.some((spot) => spot.label === state.selectedSpotLabel && !spot.isBlocked);
  if (!exists || !isSpotFreeForSelectedDay(state.selectedSpotLabel)) setSelectedSpot("");
}

function isSpotFreeForSelectedDay(label) {
  const key = normalizedSpotKey(label);
  const isBlocked = state.spots.some((spot) => spot.isBlocked && normalizedSpotKey(spot.label) === key);
  if (isBlocked) return false;
  return !state.dayBookings.some((booking) => normalizedSpotKey(booking.spot) === key);
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
  const rawDate = data.bookingDate ?? data.date ?? data.booking_day ?? data.bookingDateString;
  const bookingDate = parseDateLike(rawDate);
  if (!(bookingDate instanceof Date) || Number.isNaN(bookingDate.getTime())) return null;

  const rawSpot = data.spot ?? data.spotLabel ?? data.spotId ?? data.spotID ?? data.spotNumber ?? data.spotNo ?? "";
  const spot = normalizeSpotLabel(rawSpot);
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
  if (!value) return null;
  const trimmed = String(value).trim();
  if (!trimmed) return null;

  const czechLike = trimmed.match(/^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$/);
  if (czechLike) {
    const d = Number(czechLike[1]);
    const m = Number(czechLike[2]);
    const y = Number(czechLike[3]);
    if (Number.isFinite(y) && Number.isFinite(m) && Number.isFinite(d)) {
      return new Date(y, m - 1, d, 0, 0, 0, 0);
    }
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return dayStart(value);
  }
  return new Date(value);
}

function parseDateLike(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value?.toDate === "function") return value.toDate();
  if (typeof value === "number") return new Date(value);
  if (typeof value === "string") return parseBookingDateString(value);
  if (typeof value === "object") {
    const seconds = Number(value.seconds ?? value._seconds);
    const nanos = Number(value.nanoseconds ?? value._nanoseconds ?? 0);
    if (Number.isFinite(seconds)) {
      const millis = seconds * 1000 + (Number.isFinite(nanos) ? Math.floor(nanos / 1_000_000) : 0);
      return new Date(millis);
    }
  }
  return null;
}

function normalizeSpotLabel(raw) {
  const value = String(raw ?? "").trim();
  if (!value) return "";
  if (/^\d+$/.test(value)) return `Parking ${value}`;
  return value;
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

function downloadCalendarForBooking(booking) {
  if (!booking?.bookingDate || !booking?.fromTime || !booking?.toTime) return;

  const startsAt = combineDateAndTime(booking.bookingDate, booking.fromTime);
  const endsAt = combineDateAndTime(booking.bookingDate, booking.toTime);
  if (!startsAt || !endsAt) return;

  const spotLabel = `Spot ${extractSpotNumber(booking.spot)}`;
  const bookingDateText = formatLongDate(booking.bookingDate);
  const uid = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
  const title = `EL Parking - ${spotLabel}`;
  const description = `${spotLabel} booked on ${bookingDateText}, ${booking.fromTime}-${booking.toTime}.`;
  const location = "Rohanske nabrezi 721/39, Praha";

  const ics = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//EL Parking//Booking Calendar//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    "BEGIN:VEVENT",
    `UID:${escapeIcsText(uid)}@elparking.app`,
    `DTSTAMP:${toIcsUtc(new Date())}`,
    `DTSTART:${toIcsUtc(startsAt)}`,
    `DTEND:${toIcsUtc(endsAt)}`,
    `SUMMARY:${escapeIcsText(title)}`,
    `DESCRIPTION:${escapeIcsText(description)}`,
    `LOCATION:${escapeIcsText(location)}`,
    "END:VEVENT",
    "END:VCALENDAR",
  ].join("\r\n");

  const blob = new Blob([ics], { type: "text/calendar;charset=utf-8" });
  const fileName = `el-parking-${extractSpotNumber(booking.spot)}-${toYmd(booking.bookingDate)}.ics`;
  const downloadUrl = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = downloadUrl;
  link.download = fileName;
  link.rel = "noopener";
  document.body.append(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(downloadUrl), 1000);
}

function combineDateAndTime(date, time) {
  const [hour, minute] = String(time || "")
    .split(":")
    .map(Number);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return new Date(
    date.getFullYear(),
    date.getMonth(),
    date.getDate(),
    hour,
    minute,
    0,
    0
  );
}

function toIcsUtc(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  const hh = String(date.getUTCHours()).padStart(2, "0");
  const mm = String(date.getUTCMinutes()).padStart(2, "0");
  const ss = String(date.getUTCSeconds()).padStart(2, "0");
  return `${y}${m}${d}T${hh}${mm}${ss}Z`;
}

function escapeIcsText(value) {
  return String(value ?? "")
    .replace(/\\/g, "\\\\")
    .replace(/\r?\n/g, "\\n")
    .replace(/,/g, "\\,")
    .replace(/;/g, "\\;");
}

function friendlyAuthError(err) {
  const code = err?.code || "";
  if (code.includes("invalid-credential")) return "Invalid email or password.";
  if (code.includes("too-many-requests")) return "Too many attempts, try again shortly.";
  if (code.includes("network-request-failed")) return "Network error. Check connection.";
  return "Sign in failed.";
}

boot();
