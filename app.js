import { initializeApp } from "https://www.gstatic.com/firebasejs/11.7.1/firebase-app.js";
import {
  browserLocalPersistence,
  browserSessionPersistence,
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  setPersistence,
  signInWithEmailAndPassword,
  signOut,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-auth.js";
import {
  collection,
  deleteDoc,
  doc,
  getDocsFromServer,
  getDoc,
  getFirestore,
  onSnapshot,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from "https://www.gstatic.com/firebasejs/11.7.1/firebase-firestore.js";
import { firebaseConfig } from "./firebase-config.js";

const APP_RULES = {
  selfBookingMaxAdvanceDays: 3,
  selfBookingMaxPerDay: 1,
  bookingRetentionDays: 2,
};

const CAR_MAKES = [
  "Škoda",
  "Hyundai",
  "Toyota",
  "Volkswagen",
  "Kia",
  "Dacia",
  "Ford",
  "Mercedes-Benz",
  "Renault",
  "BMW",
  "Audi",
  "Volvo",
  "Tesla",
  "MG",
  "Nissan",
  "Peugeot",
  "MINI",
  "Subaru",
  "Porsche",
  "Honda",
  "Alfa Romeo",
  "Opel",
  "Mazda",
  "Citroën",
  "Seat",
];

const MODELS_BY_MAKE = {
  "Škoda": ["Octavia", "Octavia RS", "Octavia Combi Style", "Kamiq", "Karoq", "Karoq Style", "Kodiaq", "Fabia", "Scala", "Superb", "Superb Combi L&K", "Enyaq", "Elroq"],
  Hyundai: ["i20", "i30", "Tucson", "Kona", "Bayon", "Santa Fe", "IONIQ 5", "IONIQ 6"],
  Toyota: ["Corolla", "Yaris", "Yaris Cross", "RAV4", "C-HR", "Camry"],
  Volkswagen: ["Golf", "Golf Variant", "Tiguan", "Tiguan 2.0 TSI Elegance", "Passat", "T-Roc", "Polo", "Touareg", "ID.3", "ID.4"],
  Kia: ["Ceed", "Sportage", "Sorento", "Niro", "EV6", "EV9", "Picanto"],
  Dacia: ["Duster", "Jogger", "Sandero", "Spring"],
  Ford: ["Focus", "Kuga", "Puma", "Mustang Mach-E"],
  "Mercedes-Benz": ["A-Class", "C-Class", "C 220 d 4MATIC", "E-Class", "GLA", "GLC", "GLE", "EQA", "EQA 250", "EQB"],
  Renault: ["Clio", "Captur", "Megane", "Austral", "Arkana", "Kangoo"],
  BMW: ["3 Series", "5 Series", "X1", "X3", "X5", "i4", "iX"],
  Audi: ["A3", "A4", "A4 Avant B9", "A4 Avant 35 TDI S-Line", "A6", "Q3", "Q5", "Q7", "Q8", "Q4", "Q4 e-tron"],
  Volvo: ["EX30", "XC40", "XC60", "XC90", "V60", "V90"],
  Tesla: ["Model 3", "Model Y", "Model S", "Model X"],
  MG: ["ZS", "HS", "MG4", "Marvel R"],
  Nissan: ["Qashqai", "Juke", "X-Trail", "Leaf"],
  Peugeot: ["208", "308", "3008", "5008", "Rifter"],
  MINI: ["Cooper", "Countryman", "Countryman Electric"],
  Subaru: ["Outback", "Forester", "Crosstrek", "Impreza"],
  Porsche: ["911", "Cayenne", "Macan", "Taycan"],
  Honda: ["Civic", "CR-V", "HR-V", "Jazz"],
  "Alfa Romeo": ["Giulia", "Stelvio", "Tonale"],
  Opel: ["Corsa", "Astra", "Mokka", "Grandland"],
  Mazda: ["Mazda 2", "Mazda 3", "CX-30", "CX-5", "CX-60"],
  Citroën: ["C3", "C4", "C5 Aircross", "Berlingo"],
  Seat: ["Ibiza", "Leon", "Ateca", "Tarraco"],
};

const MAKER_LOGOS = {
  "Alfa Romeo": "car_maker_logo_alfa_romeo",
  Audi: "car_maker_logo_audi",
  BMW: "car_maker_logo_bmw",
  Citroën: "car_maker_logo_citroen",
  Dacia: "car_maker_logo_dacia",
  Ford: "car_maker_logo_ford",
  Honda: "car_maker_logo_honda",
  Hyundai: "car_maker_logo_hyundai",
  Kia: "car_maker_logo_kia",
  Mazda: "car_maker_logo_mazda",
  "Mercedes-Benz": "car_maker_logo_mercedes_benz",
  MG: "car_maker_logo_mg",
  MINI: "car_maker_logo_mini",
  Nissan: "car_maker_logo_nissan",
  Opel: "car_maker_logo_opel",
  Peugeot: "car_maker_logo_peugeot",
  Porsche: "car_maker_logo_porsche",
  Renault: "car_maker_logo_renault",
  Seat: "car_maker_logo_seat",
  Škoda: "car_maker_logo_skoda",
  Subaru: "car_maker_logo_subaru",
  Tesla: "car_maker_logo_tesla",
  Toyota: "car_maker_logo_toyota",
  Volkswagen: "car_maker_logo_volkswagen",
  Volvo: "car_maker_logo_volvo",
};

const VEHICLE_PRESETS = [
  { id: "volvo_ex30_yellow", make: "Volvo", models: ["EX30"], title: "Volvo EX30 · Moss Yellow", asset: "vehicle_mini_volvo_ex30_moss_yellow_yellow" },
  { id: "octavia_combi_style", make: "Škoda", models: ["Octavia", "Octavia Combi Style"], title: "Škoda Octavia Combi Style", asset: "vehicle_mini_skoda_octavia_combi_style" },
  { id: "skoda_superb_white", make: "Škoda", models: ["Superb"], title: "Škoda Superb · White", asset: "vehicle_mini_superb_white" },
  { id: "skoda_superb_combi_lk", make: "Škoda", models: ["Superb Combi L&K"], title: "Škoda Superb Combi L&K", asset: "vehicle_mini_skoda_superb_combi_lk" },
  { id: "skoda_kodiaq", make: "Škoda", models: ["Kodiaq"], title: "Škoda Kodiaq", asset: "vehicle_mini_skoda_kodiaq" },
  { id: "skoda_kodiaq_gray", make: "Škoda", models: ["Kodiaq"], title: "Škoda Kodiaq · Gray", asset: "vehicle_mini_skoda_kodiaq_gray" },
  { id: "skoda_karoq_style", make: "Škoda", models: ["Karoq", "Karoq Style"], title: "Škoda Karoq Style", asset: "vehicle_mini_skoda_karoq_style" },
  { id: "vw_tiguan", make: "Volkswagen", models: ["Tiguan", "Tiguan 2.0 TSI Elegance"], title: "Volkswagen Tiguan", asset: "vehicle_mini_vw_tiguan" },
  { id: "vw_golf_variant", make: "Volkswagen", models: ["Golf", "Golf Variant"], title: "Volkswagen Golf Variant", asset: "vehicle_mini_vw_golf_variant" },
  { id: "vw_caddy_maxi", make: "Volkswagen", models: ["Caddy", "Caddy Maxi"], title: "Volkswagen Caddy Maxi", asset: "vehicle_mini_van_white" },
  { id: "mercedes_eqa_250", make: "Mercedes-Benz", models: ["EQA", "EQA 250", "EQA 250 Premium Plus"], title: "Mercedes EQA 250", asset: "vehicle_mini_electric_crossover_silver" },
  { id: "mercedes_gla", make: "Mercedes-Benz", models: ["GLA", "GLA 200"], title: "Mercedes GLA 200", asset: "vehicle_mini_compact_suv_white" },
  { id: "mercedes_c220d_4matic", make: "Mercedes-Benz", models: ["C-Class", "C 220 d 4MATIC"], title: "Mercedes C 220 d 4MATIC", asset: "vehicle_mini_mercedes_c220d_4matic" },
  { id: "bmw_i4", make: "BMW", models: ["i4"], title: "BMW i4", asset: "vehicle_mini_bmw_i4" },
  { id: "bmw_3_black", make: "BMW", models: ["3 Series"], title: "BMW 3 Series · Black", asset: "vehicle_mini_bmw_3_black" },
  { id: "audi_q4", make: "Audi", models: ["Q4", "Q4 Sportback", "Q4 e-tron", "Q4 Sportback 40 e-tron"], title: "Audi Q4 Sportback", asset: "vehicle_mini_electric_crossover_silver" },
  { id: "audi_a4_avant_b9", make: "Audi", models: ["A4", "A4 Avant B9", "A4 Avant 35 TDI S-Line"], title: "Audi A4 Avant", asset: "vehicle_mini_audi_a4_avant_b9" },
  { id: "alfa_romeo_stelvio", make: "Alfa Romeo", models: ["Stelvio"], title: "Alfa Romeo Stelvio", asset: "vehicle_mini_alfa_romeo_stelvio" },
  { id: "mini_countryman_black", make: "MINI", models: ["Countryman"], title: "MINI Countryman · Black", asset: "vehicle_mini_mini_countryman_black" },
];

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
  users: [],
  announcements: [],
  adminAnnouncements: [],
  infoItems: [],
  lastBookedSummary: null,
  selectedVehicleMake: "",
  selectedVehicleModel: "",
  selectedVehiclePresetID: "",
  confirmResolver: null,
  editingContent: null,
  bookingsFilter: "upcoming",
  profileDirty: false,
  bulkSelectedIds: new Set(),
  spotsReady: false,
  bookingsReady: false,
  listeners: {
    allBookings: null,
    spots: null,
    announcements: null,
    infoItems: null,
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
  forgotPasswordBtn: byId("forgotPasswordBtn"),
  emailInput: byId("emailInput"),
  passwordInput: byId("passwordInput"),
  rememberMeInput: byId("rememberMeInput"),
  pendingSignOut: byId("pendingSignOut"),
  finishView: byId("finishView"),
  finishRegForm: byId("finishRegForm"),
  finishPlate: byId("finishPlate"),
  finishCar: byId("finishCar"),
  finishSubmit: byId("finishSubmit"),
  finishError: byId("finishError"),
  finishSignOut: byId("finishSignOut"),
  signOutButton: byId("signOutButton"),
  greetingText: byId("greetingText"),
  heroState: byId("heroState"),
  heroDate: byId("heroDate"),
  heroSpot: byId("heroSpot"),
  heroTime: byId("heroTime"),
  announcementsList: byId("announcementsList"),
  refreshHome: byId("refreshHome"),
  infoList: byId("infoList"),
  infoCardsSection: byId("infoCardsSection"),
  toastContainer: byId("toastContainer"),
  bookingsFilter: byId("bookingsFilter"),
  bookingSuccessSummary: byId("bookingSuccessSummary"),
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
  adminRefresh: byId("adminRefresh"),
  usersTotal: byId("usersTotal"),
  usersActive: byId("usersActive"),
  usersPending: byId("usersPending"),
  adminTotalBookings: byId("adminTotalBookings"),
  adminPinnedAnnouncements: byId("adminPinnedAnnouncements"),
  adminInfoCards: byId("adminInfoCards"),
  adminUserSearch: byId("adminUserSearch"),
  adminUsersList: byId("adminUsersList"),
  adminSpotsSummary: byId("adminSpotsSummary"),
  adminSpotsGrid: byId("adminSpotsGrid"),
  adminNewAnnouncement: byId("adminNewAnnouncement"),
  adminAnnouncementsList: byId("adminAnnouncementsList"),
  adminNewInfoCard: byId("adminNewInfoCard"),
  adminInfoList: byId("adminInfoList"),
  profileForm: byId("profileForm"),
  nameInput: byId("nameInput"),
  vocativeInput: byId("vocativeInput"),
  plateInput: byId("plateInput"),
  carInput: byId("carInput"),
  vehiclePreview: byId("vehiclePreview"),
  vehicleMakeButton: byId("vehicleMakeButton"),
  vehicleMakeLabel: byId("vehicleMakeLabel"),
  vehicleModelSelect: byId("vehicleModelSelect"),
  makePickerModal: byId("makePickerModal"),
  makePickerList: byId("makePickerList"),
  makePickerClose: byId("makePickerClose"),
  vehicleIconButton: byId("vehicleIconButton"),
  vehicleIconLabel: byId("vehicleIconLabel"),
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
  spotDetailsModal: byId("spotDetailsModal"),
  spotDetailsTitle: byId("spotDetailsTitle"),
  spotDetailsMeta: byId("spotDetailsMeta"),
  spotDetailsList: byId("spotDetailsList"),
  spotDetailsClose: byId("spotDetailsClose"),
  vehiclePickerModal: byId("vehiclePickerModal"),
  vehiclePickerTitle: byId("vehiclePickerTitle"),
  vehiclePickerMeta: byId("vehiclePickerMeta"),
  vehiclePickerList: byId("vehiclePickerList"),
  vehiclePickerClose: byId("vehiclePickerClose"),
  confirmModal: byId("confirmModal"),
  confirmTitle: byId("confirmTitle"),
  confirmMessage: byId("confirmMessage"),
  confirmCancel: byId("confirmCancel"),
  confirmAccept: byId("confirmAccept"),
  adminContentModal: byId("adminContentModal"),
  adminContentForm: byId("adminContentForm"),
  adminContentTitle: byId("adminContentTitle"),
  adminContentIcon: byId("adminContentIcon"),
  adminContentTitleInput: byId("adminContentTitleInput"),
  adminContentBody: byId("adminContentBody"),
  adminContentImageField: byId("adminContentImageField"),
  adminContentImageURL: byId("adminContentImageURL"),
  adminAnnouncementOptions: byId("adminAnnouncementOptions"),
  adminContentActive: byId("adminContentActive"),
  adminContentPinned: byId("adminContentPinned"),
  adminInfoLinkField: byId("adminInfoLinkField"),
  adminContentLinkURL: byId("adminContentLinkURL"),
  adminContentError: byId("adminContentError"),
  adminContentDelete: byId("adminContentDelete"),
  adminContentCancel: byId("adminContentCancel"),
  adminContentSave: byId("adminContentSave"),
  spotSearch: byId("spotSearch"),
  bookingsBadge: byId("bookingsBadge"),
  adminTodayBar: byId("adminTodayBar"),
  adminTodayBooked: byId("adminTodayBooked"),
  adminTodayFree: byId("adminTodayFree"),
  themeToggleBtn: byId("themeToggleBtn"),
  tutorialHelpBtn: byId("tutorialHelpBtn"),
  tutorialModal: byId("tutorialModal"),
  tutorialBody: byId("tutorialBody"),
  tutorialDots: byId("tutorialDots"),
  tutorialBack: byId("tutorialBack"),
  tutorialNext: byId("tutorialNext"),
  tutorialSkip: byId("tutorialSkip"),
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

function showToast(message, type = "info") {
  if (!ui.toastContainer) return;
  const toast = document.createElement("div");
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  ui.toastContainer.append(toast);
  requestAnimationFrame(() => toast.classList.add("toast-visible"));
  setTimeout(() => {
    toast.classList.remove("toast-visible");
    toast.addEventListener("transitionend", () => toast.remove(), { once: true });
  }, 3500);
}

function setupPullToRefresh() {
  const homeTab = document.getElementById("homeTab");
  if (!homeTab) return;
  let startY = 0;
  let pulling = false;
  homeTab.addEventListener("touchstart", (e) => {
    if (homeTab.scrollTop === 0) { startY = e.touches[0].clientY; pulling = true; }
  }, { passive: true });
  homeTab.addEventListener("touchend", (e) => {
    if (!pulling) return;
    const dist = e.changedTouches[0].clientY - startY;
    if (dist > 64) { renderAnnouncements(); renderInfoCards(); showToast("Refreshed."); }
    pulling = false;
  }, { passive: true });
}

function bootstrap() {
  if (ui.bookDate) ui.bookDate.value = state.selectedDate;
  if (ui.rememberMeInput) ui.rememberMeInput.checked = shouldKeepSignedIn();
  initThemeToggle();
  bindEvents();
  syncBookUiState();
  onAuthStateChanged(auth, handleAuthState);
}

function applyTheme(pref) {
  const isDark = pref === "dark" ||
    (pref !== "light" && window.matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.classList.toggle("dark-mode", isDark);
}

function initThemeToggle() {
  window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if (!localStorage.getItem("el-parking-theme")) applyTheme("auto");
  });
}

function bindEvents() {
  ui.loginForm?.addEventListener("submit", onLoginSubmit);
  ui.forgotPasswordBtn?.addEventListener("click", onForgotPassword);
  ui.tutorialHelpBtn?.addEventListener("click", openTutorial);
  ui.tutorialNext?.addEventListener("click", tutorialNext);
  ui.tutorialBack?.addEventListener("click", tutorialBack);
  ui.tutorialSkip?.addEventListener("click", closeTutorial);
  ui.signOutButton?.addEventListener("click", () => signOut(auth));
  ui.pendingSignOut?.addEventListener("click", () => signOut(auth));
  ui.finishRegForm?.addEventListener("submit", onFinishRegSubmit);
  ui.finishSignOut?.addEventListener("click", () => signOut(auth));
  ui.refreshHome?.addEventListener("click", () => { renderAnnouncements(); renderInfoCards(); });
  ui.refreshBookings?.addEventListener("click", () => renderMyBookings());
  ui.bookingsFilter?.addEventListener("click", (e) => {
    const btn = e.target.closest(".bookings-filter-btn");
    if (!btn) return;
    state.bookingsFilter = btn.dataset.filter;
    ui.bookingsFilter.querySelectorAll(".bookings-filter-btn").forEach((b) => b.classList.toggle("active", b === btn));
    renderMyBookings();
  });
  ui.adminRefresh?.addEventListener("click", refreshAdminFromServer);
  ui.adminUserSearch?.addEventListener("input", renderAdminUsers);
  ui.adminNewAnnouncement?.addEventListener("click", () => openContentModal("announcement"));
  ui.adminNewInfoCard?.addEventListener("click", () => openContentModal("info"));
  ui.adminContentCancel?.addEventListener("click", closeContentModal);
  ui.adminContentDelete?.addEventListener("click", deleteCurrentContent);
  ui.adminContentForm?.addEventListener("submit", saveCurrentContent);
  ui.adminContentModal?.addEventListener("click", (event) => {
    if (event.target === ui.adminContentModal) closeContentModal();
  });
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
  ui.vehicleMakeButton?.addEventListener("click", openMakePicker);
  ui.vehicleModelSelect?.addEventListener("change", () => {
    state.selectedVehicleModel = ui.vehicleModelSelect.value;
    if (!presetMatchesVehicle(state.selectedVehiclePresetID, state.selectedVehicleMake, state.selectedVehicleModel)) {
      state.selectedVehiclePresetID = "";
    }
    syncCarDescriptionField();
    renderVehiclePreview();
  });
  ui.vehicleIconButton?.addEventListener("click", openVehiclePicker);
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
  ui.spotDetailsClose?.addEventListener("click", closeSpotDetailsModal);
  ui.spotDetailsModal?.addEventListener("click", (event) => {
    if (event.target === ui.spotDetailsModal) closeSpotDetailsModal();
  });
  ui.makePickerClose?.addEventListener("click", closeMakePicker);
  ui.makePickerModal?.addEventListener("click", (event) => {
    if (event.target === ui.makePickerModal) closeMakePicker();
  });
  ui.vehiclePickerClose?.addEventListener("click", closeVehiclePicker);
  ui.vehiclePickerModal?.addEventListener("click", (event) => {
    if (event.target === ui.vehiclePickerModal) closeVehiclePicker();
  });
  ui.confirmCancel?.addEventListener("click", () => resolveConfirm(false));
  ui.confirmAccept?.addEventListener("click", () => resolveConfirm(true));
  ui.confirmModal?.addEventListener("click", (event) => {
    if (event.target === ui.confirmModal) resolveConfirm(false);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      hideBookingSuccessModal();
      closeBookingEditModal();
      closeSpotDetailsModal();
      closeMakePicker();
      closeVehiclePicker();
      resolveConfirm(false);
      closeContentModal();
    }
  });
  ui.spotSearch?.addEventListener("input", () => renderParking());

  ui.themeToggleBtn?.addEventListener("click", () => {
    const isDark = document.documentElement.classList.contains("dark-mode");
    const next = isDark ? "light" : "dark";
    localStorage.setItem("el-parking-theme", next);
    applyTheme(next);
  });

  ui.tabs.forEach((tab) => tab.addEventListener("click", () => {
    if (tab.dataset.tab !== "settings" && state.profileDirty) {
      if (!window.confirm("You have unsaved profile changes. Leave anyway?")) return;
      state.profileDirty = false;
    }
    switchTab(tab.dataset.tab);
  }));

  const profileFields = ["nameInput", "vocativeInput", "plateInput", "vehicleModelSelect"];
  profileFields.forEach((id) => {
    ui[id]?.addEventListener("input", () => { state.profileDirty = true; });
    ui[id]?.addEventListener("change", () => { state.profileDirty = true; });
  });

  setupPullToRefresh();
}

async function handleAuthState(user) {
  clearAllListeners();
  state.user = user;
  state.profile = null;
  state.spots = [];
  state.allBookings = [];
  state.dayBookings = [];
  state.myBookings = [];
  state.users = [];
  state.announcements = [];
  state.adminAnnouncements = [];
  state.infoItems = [];
  state.lastBookedSummary = null;
  state.selectedVehicleMake = "";
  state.selectedVehicleModel = "";
  state.selectedVehiclePresetID = "";
  state.editingContent = null;
  state.spotsReady = false;
  state.bookingsReady = false;
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
  const status = (state.profile.status || "pending").toLowerCase();

  if (status !== "active") {
    showOnly("pending");
    return;
  }

  // First sign-in for admin-provisioned accounts: require plate + car before entering.
  const needsFinish =
    state.profile.needsFinishRegistration ||
    !state.profile.registrationPlate ||
    !state.profile.carDescription;
  if (needsFinish) {
    showFinishRegistration();
    return;
  }

  enterApp();
}

function enterApp() {
  const role = (state.profile.role || "user").toLowerCase();
  showOnly("app");
  ui.adminTab.classList.toggle("hidden", !(role === "admin" || role === "privileged"));
  if (role !== "admin" && role !== "privileged" && currentTab() === "admin") {
    switchTab("home");
  }
  hydrateProfileForm();
  renderGreeting();
  switchTab("home");
  subscribeCoreData();
  maybeShowTutorial();
}

function showFinishRegistration() {
  showOnly("finish");
  ui.finishPlate.value = state.profile.registrationPlate || "";
  ui.finishCar.value = state.profile.carDescription || "";
  ui.finishError.textContent = "";
}

// ── First-run tutorial (mirrors the iOS/Android onboarding) ──────────────────
const TUTORIAL_SEEN_KEY = "el-parking-tutorial-seen";
const SVG = {
  park: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="4"/><path d="M9 17V7h4a3 3 0 0 1 0 6H9"/></svg>',
  grid: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/></svg>',
  calendar: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
  clock: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15 14"/></svg>',
  bell: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>',
  list: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>',
  car: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 13l1.5-4.5A2 2 0 0 1 8.4 7h7.2a2 2 0 0 1 1.9 1.5L19 13"/><path d="M5 13h14v4a1 1 0 0 1-1 1h-1a1 1 0 0 1-1-1v-1H8v1a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1z"/><circle cx="7.5" cy="13.5" r=".5"/><circle cx="16.5" cy="13.5" r=".5"/></svg>',
  shield: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3l8 3v6c0 4.5-3.2 7.7-8 9-4.8-1.3-8-4.5-8-9V6z"/><polyline points="9 12 11 14 15 10"/></svg>',
};

const TUTORIAL_STEPS = [
  {
    icon: SVG.park,
    title: "Welcome to EL Parking",
    intro: "Reserve a spot in the Karlín office garage in seconds — right from your browser.",
    rows: [],
  },
  {
    icon: SVG.grid,
    title: "Find & book a spot",
    rows: [
      [SVG.calendar, "Pick a day", "Use the day selector at the top of the Parking tab."],
      [SVG.grid, "Choose a free spot", "Green spots are free — tap one to select it."],
      [SVG.clock, "Set your time", "Adjust the from/to times and confirm. Done."],
    ],
  },
  {
    icon: SVG.bell,
    title: "Manage your bookings",
    rows: [
      [SVG.list, "My Bookings", "View, edit or cancel your reservations any time."],
      [SVG.car, "Your vehicle", "Add your plate + car so colleagues know whose spot it is."],
    ],
  },
  {
    icon: SVG.shield,
    title: "Good to know",
    rows: [
      [SVG.calendar, "Booking windows", "Spots open on a rolling schedule — book early."],
      [SVG.shield, "Be considerate", "Cancel if plans change; repeated no-shows earn warnings."],
    ],
  },
];

let tutorialStep = 0;

function renderTutorialStep() {
  const step = TUTORIAL_STEPS[tutorialStep];
  const rows = (step.rows || [])
    .map(
      ([icon, title, desc]) =>
        `<div class="tutorial-row"><span class="tutorial-row-icon">${icon}</span><div><strong>${title}</strong><p>${desc}</p></div></div>`
    )
    .join("");
  ui.tutorialBody.innerHTML =
    `<div class="tutorial-hero">${step.icon}</div>` +
    `<h3 id="tutorialTitle">${step.title}</h3>` +
    (step.intro ? `<p class="tutorial-intro">${step.intro}</p>` : "") +
    (rows ? `<div class="tutorial-rows">${rows}</div>` : "");
  ui.tutorialDots.innerHTML = TUTORIAL_STEPS.map(
    (_, i) => `<span class="tutorial-dot${i === tutorialStep ? " active" : ""}"></span>`
  ).join("");
  const last = tutorialStep === TUTORIAL_STEPS.length - 1;
  ui.tutorialBack.classList.toggle("hidden", tutorialStep === 0);
  ui.tutorialNext.textContent = last ? "Get started" : "Next";
}

function openTutorial() {
  tutorialStep = 0;
  renderTutorialStep();
  ui.tutorialModal.classList.remove("hidden");
}

function closeTutorial() {
  ui.tutorialModal.classList.add("hidden");
  try { localStorage.setItem(TUTORIAL_SEEN_KEY, "1"); } catch (_) {}
}

function tutorialNext() {
  if (tutorialStep < TUTORIAL_STEPS.length - 1) {
    tutorialStep += 1;
    renderTutorialStep();
  } else {
    closeTutorial();
  }
}

function tutorialBack() {
  if (tutorialStep > 0) {
    tutorialStep -= 1;
    renderTutorialStep();
  }
}

function maybeShowTutorial() {
  let seen = false;
  try { seen = localStorage.getItem(TUTORIAL_SEEN_KEY) === "1"; } catch (_) {}
  if (!seen) openTutorial();
}

async function onFinishRegSubmit(event) {
  event.preventDefault();
  const plate = ui.finishPlate.value.trim().toUpperCase();
  const car = ui.finishCar.value.trim();
  ui.finishError.textContent = "";
  if (!plate || !car) {
    ui.finishError.textContent = "Please fill in both fields.";
    return;
  }
  ui.finishSubmit.disabled = true;
  try {
    await updateDoc(doc(db, "users", state.user.uid), {
      registrationPlate: plate,
      carDescription: car,
      needsFinishRegistration: false,
    });
    state.profile.registrationPlate = plate;
    state.profile.carDescription = car;
    state.profile.needsFinishRegistration = false;
    enterApp();
  } catch (e) {
    ui.finishError.textContent = "Could not save — please try again.";
  } finally {
    ui.finishSubmit.disabled = false;
  }
}

async function onForgotPassword() {
  const email = ui.emailInput.value.trim().toLowerCase();
  if (!email) {
    ui.authError.textContent = "Enter your email above first, then tap Forgot password.";
    ui.emailInput.focus();
    return;
  }
  ui.authError.textContent = "";
  ui.forgotPasswordBtn.disabled = true;
  try {
    await sendPasswordResetEmail(auth, email);
    showToast(`If an account exists for ${email}, a reset link has been sent.`);
  } catch (err) {
    showToast(friendlyAuthError(err), "error");
  } finally {
    ui.forgotPasswordBtn.disabled = false;
  }
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
  subscribeInfoItems();
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
      state.spotsReady = true;
      renderSpotSelect();
      ensureSelectedSpotIsValid();
      recalculateDerivedBookings();
      renderParking();
      renderAdminSpots();
      renderDayPills();
    },
    () => {
      state.spots = [];
      renderSpotSelect();
      recalculateDerivedBookings();
      renderParking();
      renderAdminSpots();
      renderDayPills();
    }
  );
}

function subscribeAllBookings() {
  state.listeners.allBookings?.();
  let didRunBookingsPurge = false; // per-session cleanup, runs once per listener attach
  state.listeners.allBookings = onSnapshot(
    collection(db, "bookings"),
    (snap) => {
      const loaded = snap.docs
        .map((d) => parseBooking(d.id, d.data()))
        .filter(Boolean)
        .filter(shouldKeepBookingLocally)
        .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime());
      state.allBookings = loaded;
      state.bookingsReady = true;
      // Once-per-session cleanup (admin only). The loaded list only spans recent days,
      // so it can't see old docs — query them directly with an inequality on
      // bookingDate and delete. Only admins may delete others' bookings (Firestore
      // rules), so this keeps the WHOLE collection small → reads stay cheap at scale.
      if (!didRunBookingsPurge && (state.profile?.role || "").toLowerCase() === "admin") {
        didRunBookingsPurge = true;
        const cutoff = new Date();
        cutoff.setHours(0, 0, 0, 0);
        cutoff.setDate(cutoff.getDate() - APP_RULES.bookingRetentionDays);
        getDocsFromServer(
          query(collection(db, "bookings"), where("bookingDate", "<", Timestamp.fromDate(cutoff)))
        )
          .then((snap) => snap.forEach((d) => deleteDoc(doc(db, "bookings", d.id)).catch(() => {})))
          .catch(() => {});
      }
      recalculateDerivedBookings();
      ensureSelectedSpotIsValid();
      renderHomeHero();
      renderMyBookings();
      renderParking();
      renderAdminSpotInspector();
      renderAdminDashboard();
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
      renderAdminDashboard();
      renderDayPills();
    }
  );
}

function subscribeAnnouncements() {
  state.listeners.announcements?.();
  state.listeners.announcements = onSnapshot(
    collection(db, "announcements"),
    (snap) => {
      state.adminAnnouncements = snap.docs
        .map((d) => parseAnnouncement(d.id, d.data()))
        .filter(Boolean)
        .sort((a, b) => (b.createdAtMs || 0) - (a.createdAtMs || 0))
        .slice(0, 50);
      state.announcements = state.adminAnnouncements.filter((item) => item?.isActive).slice(0, 12);
      renderAnnouncements();
      renderAdminAnnouncements();
      renderAdminDashboard();
    },
    () => {
      state.announcements = [];
      state.adminAnnouncements = [];
      renderAnnouncements();
      renderAdminAnnouncements();
      renderAdminDashboard();
    }
  );
}

function subscribeInfoItems() {
  state.listeners.infoItems?.();
  state.listeners.infoItems = onSnapshot(
    collection(db, "info_items"),
    (snap) => {
      state.infoItems = snap.docs
        .map((d) => parseInfoItem(d.id, d.data()))
        .filter(Boolean)
        .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
      renderInfoCards();
      renderAdminInfoItems();
      renderAdminDashboard();
    },
    () => {
      state.infoItems = [];
      renderInfoCards();
      renderAdminInfoItems();
      renderAdminDashboard();
    }
  );
}

function subscribeAdminStatsIfAllowed() {
  state.listeners.users?.();
  if (!state.profile || !["admin", "privileged"].includes((state.profile.role || "").toLowerCase())) {
    return;
  }
  state.listeners.users = onSnapshot(collection(db, "users"), (snap) => {
    state.users = snap.docs.map((d) => parseUser(d.data(), d.id));
    renderAdminDashboard();
    renderAdminUsers();
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

function renderAdminDashboard() {
  if (!isAdminLike()) return;
  const users = state.users || [];
  ui.usersTotal.textContent = String(users.length);
  ui.usersActive.textContent = String(users.filter((u) => (u.status || "").toLowerCase() === "active").length);
  ui.usersPending.textContent = String(users.filter((u) => (u.status || "").toLowerCase() === "pending").length);
  ui.adminTotalBookings.textContent = String(state.allBookings.length);
  ui.adminPinnedAnnouncements.textContent = String(state.adminAnnouncements.filter((a) => a.isPinned).length);
  ui.adminInfoCards.textContent = String(state.infoItems.length);
}

function renderAdminUsers() {
  if (!ui.adminUsersList || !isAdminLike()) return;
  ui.adminUsersList.textContent = "";
  const needle = String(ui.adminUserSearch?.value || "").trim().toLowerCase();
  const users = state.users
    .filter((user) => {
      if (!needle) return true;
      return [user.displayName, user.email, user.registrationPlate, user.carDescription, user.role, user.status]
        .join(" ")
        .toLowerCase()
        .includes(needle);
    })
    .sort((a, b) => (a.displayName || a.email).localeCompare(b.displayName || b.email));

  if (!users.length) {
    ui.adminUsersList.append(textRow("No users found."));
    return;
  }

  for (const user of users) {
    const item = adminItem({
      title: `${user.displayName || user.email}${user.uid === state.user?.uid ? " · You" : ""}`,
      meta: `${user.email || "No email"} · ${user.registrationPlate || "No plate"} · ${user.carDescription || "No vehicle"}`,
    });

    const role = compactSelect(["user", "privileged", "admin"], user.role || "user");
    role.setAttribute("aria-label", `Role for ${user.displayName || user.email}`);
    role.disabled = user.uid === state.user?.uid;
    role.addEventListener("change", () => updateUserAdminFields(user, { role: role.value }));

    const status = compactSelect(["pending", "active", "suspended"], user.status || "pending");
    status.setAttribute("aria-label", `Status for ${user.displayName || user.email}`);
    status.disabled = user.uid === state.user?.uid;
    status.addEventListener("change", () => updateUserAdminFields(user, { status: status.value }));

    const reset = document.createElement("button");
    reset.type = "button";
    reset.className = "btn subtle small";
    reset.textContent = "Password Reset";
    reset.disabled = !user.email;
    reset.addEventListener("click", async () => {
      if (!user.email) return;
      if (!window.confirm(`Send password reset email to ${user.email}?`)) return;
      try {
        await sendPasswordResetEmail(auth, user.email);
        showToast("Password reset email sent.");
      } catch (error) {
        showToast(error?.message || "Password reset failed.", "error");
      }
    });

    item.actions.append(role, status, reset);
    ui.adminUsersList.append(item.root);
  }
}

function renderAdminSpots() {
  if (!ui.adminSpotsGrid || !isAdminLike()) return;
  ui.adminSpotsGrid.textContent = "";
  const blocked = state.spots.filter((spot) => spot.isBlocked).length;
  ui.adminSpotsSummary.textContent = `${state.spots.length} spots · ${blocked} blocked`;

  for (const spot of state.spots) {
    const card = document.createElement("article");
    card.className = "admin-spot-card";
    card.classList.toggle("blocked", spot.isBlocked);

    const label = document.createElement("strong");
    label.textContent = extractSpotNumber(spot.label);
    const meta = document.createElement("span");
    meta.className = "muted tiny";
    meta.textContent = spot.isBlocked ? "Blocked" : spot.isAccessible ? "Accessible" : "Open";

    const block = document.createElement("button");
    block.type = "button";
    block.className = spot.isBlocked ? "btn subtle small" : "btn danger small";
    block.textContent = spot.isBlocked ? "Unblock" : "Block";
    block.addEventListener("click", () => updateSpotAdminFields(spot, { isBlocked: !spot.isBlocked }));

    const accessible = document.createElement("button");
    accessible.type = "button";
    accessible.className = "btn subtle small";
    accessible.textContent = spot.isAccessible ? "Accessible" : "Mark Accessible";
    accessible.addEventListener("click", () => updateSpotAdminFields(spot, { isAccessible: !spot.isAccessible }));

    card.append(label, meta, block, accessible);
    ui.adminSpotsGrid.append(card);
  }
}

function renderAdminAnnouncements() {
  if (!ui.adminAnnouncementsList || !isAdminLike()) return;
  ui.adminAnnouncementsList.textContent = "";
  if (!state.adminAnnouncements.length) {
    ui.adminAnnouncementsList.append(textRow("No announcements."));
    return;
  }

  for (const item of state.adminAnnouncements) {
    const row = adminItem({
      title: `${item.emoji || "📣"} ${item.title || "Untitled"}`,
      meta: `${item.isActive ? "Active" : "Hidden"} · ${item.isPinned ? "Pinned" : "Not pinned"} · ${
        item.body || "No body"
      }`,
    });
    const edit = actionButton("Edit", "subtle", () => openContentModal("announcement", item));
    const pin = actionButton(item.isPinned ? "Unpin" : "Pin", "subtle", () =>
      saveAnnouncement({ ...item, isPinned: !item.isPinned })
    );
    const active = actionButton(item.isActive ? "Hide" : "Show", "subtle", () =>
      saveAnnouncement({ ...item, isActive: !item.isActive })
    );
    const del = actionButton("Delete", "danger", () => deleteAnnouncement(item, true));
    row.actions.append(edit, pin, active, del);
    ui.adminAnnouncementsList.append(row.root);
  }
}

function renderAdminInfoItems() {
  if (!ui.adminInfoList || !isAdminLike()) return;
  ui.adminInfoList.textContent = "";
  if (!state.infoItems.length) {
    ui.adminInfoList.append(textRow("No info cards."));
    return;
  }

  for (const item of state.infoItems) {
    const row = adminItem({
      title: `${item.icon || "info.circle.fill"} ${item.title || "Untitled"}`,
      meta: `${item.body || "No body"}${item.linkURL ? ` · ${item.linkURL}` : ""}`,
    });
    row.actions.append(
      actionButton("Edit", "subtle", () => openContentModal("info", item)),
      actionButton("Delete", "danger", () => deleteInfoItem(item))
    );
    ui.adminInfoList.append(row.root);
  }
}

function adminItem({ title, meta }) {
  const root = document.createElement("article");
  root.className = "admin-item";
  const main = document.createElement("div");
  main.className = "admin-item-main";
  const titleNode = document.createElement("p");
  titleNode.className = "admin-item-title";
  titleNode.textContent = title;
  const metaNode = document.createElement("p");
  metaNode.className = "admin-item-meta";
  metaNode.textContent = meta;
  main.append(titleNode, metaNode);
  const actions = document.createElement("div");
  actions.className = "admin-item-actions";
  root.append(main, actions);
  return { root, main, actions };
}

function actionButton(label, style, handler) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = `btn ${style || "subtle"} small`;
  button.textContent = label;
  button.addEventListener("click", handler);
  return button;
}

function compactSelect(options, value) {
  const select = document.createElement("select");
  for (const optionValue of options) {
    const option = document.createElement("option");
    option.value = optionValue;
    option.textContent = titleCase(optionValue);
    select.append(option);
  }
  select.value = value;
  return select;
}

async function updateUserAdminFields(user, patch) {
  if (!isAdminLike() || !user?.uid || user.uid === state.user?.uid) return;
  try {
    await updateDoc(doc(db, "users", user.uid), {
      ...patch,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    showToast(error?.message || "User update failed.", "error");
  }
}

async function updateSpotAdminFields(spot, patch) {
  if (!isAdminLike() || !spot?.id) return;
  try {
    await setDoc(
      doc(db, "parkingSpots", spot.id),
      {
        id: spot.id,
        label: spot.label,
        sortOrder: spot.sortOrder ?? 999,
        ...patch,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );
  } catch (error) {
    showToast(error?.message || "Spot update failed.", "error");
  }
}

function openContentModal(kind, item = null) {
  if (!isAdminLike() || !ui.adminContentModal) return;
  state.editingContent = { kind, item };
  const isAnnouncement = kind === "announcement";
  ui.adminContentTitle.textContent = item ? `Edit ${isAnnouncement ? "Announcement" : "Info Card"}` : `New ${isAnnouncement ? "Announcement" : "Info Card"}`;
  ui.adminContentIcon.value = item?.emoji || item?.icon || (isAnnouncement ? "📣" : "info.circle.fill");
  ui.adminContentTitleInput.value = item?.title || "";
  ui.adminContentBody.value = item?.body || "";
  ui.adminContentImageURL.value = item?.imageURL || "";
  ui.adminContentActive.checked = item?.isActive ?? true;
  ui.adminContentPinned.checked = item?.isPinned ?? false;
  ui.adminContentLinkURL.value = item?.linkURL || "";
  ui.adminContentImageField.classList.remove("hidden");
  ui.adminAnnouncementOptions.classList.toggle("hidden", !isAnnouncement);
  ui.adminInfoLinkField.classList.toggle("hidden", isAnnouncement);
  ui.adminContentDelete.classList.toggle("hidden", !item);
  ui.adminContentError.textContent = "";
  ui.adminContentModal.classList.remove("hidden");
  ui.adminContentModal.setAttribute("aria-hidden", "false");
}

function closeContentModal() {
  state.editingContent = null;
  ui.adminContentModal?.classList.add("hidden");
  ui.adminContentModal?.setAttribute("aria-hidden", "true");
}

async function saveCurrentContent(event) {
  event.preventDefault();
  if (!isAdminLike() || !state.editingContent) return;
  const title = ui.adminContentTitleInput.value.trim();
  const body = ui.adminContentBody.value.trim();
  if (!title || !body) {
    ui.adminContentError.textContent = "Title and body are required.";
    return;
  }

  ui.adminContentSave.disabled = true;
  ui.adminContentError.textContent = "";
  try {
    if (state.editingContent.kind === "announcement") {
      const existing = state.editingContent.item;
      await saveAnnouncement({
        id: existing?.id,
        title,
        body,
        emoji: ui.adminContentIcon.value.trim() || "📣",
        createdBy: existing?.createdBy || state.user?.email || "web-admin",
        createdAtMs: existing?.createdAtMs || Date.now(),
        isActive: Boolean(ui.adminContentActive.checked),
        isPinned: Boolean(ui.adminContentPinned.checked),
        imageURL: ui.adminContentImageURL.value.trim(),
      });
    } else {
      const existing = state.editingContent.item;
      await saveInfoItem({
        id: existing?.id,
        icon: ui.adminContentIcon.value.trim() || "info.circle.fill",
        title,
        body,
        imageURL: ui.adminContentImageURL.value.trim(),
        linkURL: ui.adminContentLinkURL.value.trim(),
        sortOrder: existing?.sortOrder ?? state.infoItems.length,
        createdAtMs: existing?.createdAtMs || Date.now(),
      });
    }
    closeContentModal();
  } catch (error) {
    ui.adminContentError.textContent = error?.message || "Save failed.";
  } finally {
    ui.adminContentSave.disabled = false;
  }
}

async function saveAnnouncement(item) {
  const id = item.id || doc(collection(db, "announcements")).id;
  await setDoc(
    doc(db, "announcements", id),
    {
      id,
      title: item.title,
      body: item.body,
      emoji: item.emoji || "📣",
      createdBy: item.createdBy || state.user?.email || "web-admin",
      createdAt: Timestamp.fromDate(new Date(item.createdAtMs || Date.now())),
      isActive: Boolean(item.isActive),
      isPinned: Boolean(item.isPinned),
      imageURL: item.imageURL || "",
      textColorMode: "auto",
      fields: [],
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
}

async function saveInfoItem(item) {
  const id = item.id || doc(collection(db, "info_items")).id;
  await setDoc(
    doc(db, "info_items", id),
    {
      icon: item.icon || "info.circle.fill",
      title: item.title,
      body: item.body,
      imageURL: item.imageURL || "",
      details: item.details || "",
      fields: [],
      linkTitle: item.linkURL ? "Open" : "",
      linkURL: item.linkURL || "",
      sortOrder: Number(item.sortOrder ?? 0),
      createdAt: Timestamp.fromDate(new Date(item.createdAtMs || Date.now())),
      updatedAt: serverTimestamp(),
    },
    { merge: true }
  );
}

async function deleteCurrentContent() {
  const item = state.editingContent?.item;
  if (!item?.id || !isAdminLike()) return;
  const ok = window.confirm(`Delete "${item.title || "this item"}"?`);
  if (!ok) return;
  try {
    if (state.editingContent.kind === "announcement") await deleteAnnouncement(item, false);
    else await deleteInfoItem(item, false);
    closeContentModal();
  } catch (error) {
    ui.adminContentError.textContent = error?.message || "Delete failed.";
  }
}

async function deleteAnnouncement(item, confirmFirst = true) {
  if (!item?.id) return;
  if (confirmFirst && !window.confirm(`Delete announcement "${item.title || "Untitled"}"?`)) return;
  await deleteDoc(doc(db, "announcements", item.id));
}

async function deleteInfoItem(item, confirmFirst = true) {
  if (!item?.id) return;
  if (confirmFirst && !window.confirm(`Delete info card "${item.title || "Untitled"}"?`)) return;
  await deleteDoc(doc(db, "info_items", item.id));
}

async function refreshAdminFromServer() {
  if (!isAdminLike()) return;
  try {
    const [usersSnap, bookingsSnap, announcementsSnap, infoSnap] = await Promise.all([
      getDocsFromServer(collection(db, "users")),
      getDocsFromServer(collection(db, "bookings")),
      getDocsFromServer(collection(db, "announcements")),
      getDocsFromServer(collection(db, "info_items")),
    ]);
    state.users = usersSnap.docs.map((d) => parseUser(d.data(), d.id));
    state.allBookings = bookingsSnap.docs
      .map((d) => parseBooking(d.id, d.data()))
      .filter(Boolean)
      .filter(shouldKeepBookingLocally)
      .sort((a, b) => a.bookingDate.getTime() - b.bookingDate.getTime());
    state.adminAnnouncements = announcementsSnap.docs
      .map((d) => parseAnnouncement(d.id, d.data()))
      .filter(Boolean)
      .sort((a, b) => (b.createdAtMs || 0) - (a.createdAtMs || 0));
    state.announcements = state.adminAnnouncements.filter((item) => item.isActive).slice(0, 12);
    state.infoItems = infoSnap.docs
      .map((d) => parseInfoItem(d.id, d.data()))
      .filter(Boolean)
      .sort((a, b) => (a.sortOrder ?? 0) - (b.sortOrder ?? 0));
    recalculateDerivedBookings();
    renderAdminDashboard();
    renderAdminUsers();
    renderAdminSpots();
    renderAdminAnnouncements();
    renderAdminInfoItems();
    renderMyBookings();
    renderParking();
    renderAnnouncements();
  } catch (error) {
    showToast(error?.message || "Admin refresh failed.", "error");
  }
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
    updateTabBadges();
    return;
  }

  const isToday = toYmd(upcoming.bookingDate) === todayKey;
  const isTomorrow = toYmd(upcoming.bookingDate) === toYmd(addDays(now, 1));
  const lead = isToday ? "Today" : isTomorrow ? "Tomorrow" : "Upcoming";
  ui.heroState.textContent = isToday ? "ACTIVE" : "UPCOMING";
  ui.heroDate.textContent = `${lead} · ${formatShortDate(upcoming.bookingDate)}`;
  ui.heroSpot.textContent = String(extractSpotNumber(upcoming.spot));
  ui.heroTime.textContent = `${upcoming.fromTime} - ${upcoming.toTime}`;
  updateTabBadges();
}

function updateTabBadges() {
  if (!ui.bookingsBadge) return;
  const now = new Date();
  const todayKey = toYmd(now);
  const hasActiveToday = state.myBookings.some(
    (b) => toYmd(b.bookingDate) === todayKey && bookingEndDate(b.bookingDate, b.toTime) >= now
  );
  ui.bookingsBadge.classList.toggle("hidden", !hasActiveToday);
}

function updateAdminTodayBar() {
  if (!ui.adminTodayBar || !isAdminLike()) return;
  const todayKey = toYmd(new Date());
  const todayBookings = state.allBookings.filter((b) => toYmd(b.bookingDate) === todayKey);
  const bookedSpots = new Set(todayBookings.map((b) => normalizedSpotKey(b.spot))).size;
  const usable = state.spots.filter((s) => !s.isBlocked).length;
  if (ui.adminTodayBooked) ui.adminTodayBooked.textContent = String(bookedSpots);
  if (ui.adminTodayFree) ui.adminTodayFree.textContent = String(Math.max(usable - bookedSpots, 0));
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

const SF_SYMBOL_EMOJI = {
  "info.circle.fill": "ℹ️",
  "info.circle": "ℹ️",
  "star.fill": "⭐",
  "star": "⭐",
  "bell.fill": "🔔",
  "bell": "🔔",
  "car.fill": "🚗",
  "car": "🚗",
  "calendar": "📅",
  "map.fill": "🗺️",
  "map": "🗺️",
  "house.fill": "🏠",
  "house": "🏠",
  "person.fill": "👤",
  "checkmark.circle.fill": "✅",
  "exclamationmark.triangle.fill": "⚠️",
  "exclamationmark.circle.fill": "⚠️",
  "bolt.fill": "⚡",
  "clock.fill": "🕐",
  "clock": "🕐",
};

function resolveIcon(icon) {
  if (!icon) return "ℹ️";
  if (/^[a-z0-9.]+$/.test(icon)) return SF_SYMBOL_EMOJI[icon] ?? "ℹ️";
  return icon;
}

function renderInfoCards() {
  if (!ui.infoList) return;
  ui.infoList.textContent = "";
  const items = state.infoItems;
  if (ui.infoCardsSection) ui.infoCardsSection.classList.toggle("hidden", !items.length);
  for (const item of items) {
    const wrap = document.createElement("article");
    wrap.className = "announcement";
    if (item.imageURL) {
      const img = document.createElement("img");
      img.className = "announcement-media";
      img.loading = "lazy";
      img.decoding = "async";
      img.src = item.imageURL;
      img.alt = item.title || "Info image";
      wrap.append(img);
    }
    const body = document.createElement("div");
    body.className = "announcement-body";
    const h = document.createElement("h4");
    h.textContent = `${resolveIcon(item.icon)} ${item.title}`;
    const p = document.createElement("p");
    p.textContent = item.body || "";
    body.append(h, p);
    if (item.linkURL) {
      const a = document.createElement("a");
      a.href = item.linkURL;
      a.textContent = item.linkTitle || "Open";
      a.target = "_blank";
      a.rel = "noopener noreferrer";
      a.className = "btn subtle small info-card-link";
      body.append(a);
    }
    wrap.append(body);
    ui.infoList.append(wrap);
  }
}

function renderDayPills() {
  ui.dayPills.textContent = "";
  if (!state.spotsReady) {
    for (let i = 0; i < 7; i++) {
      const skel = document.createElement("div");
      skel.className = "skeleton skeleton-pill";
      ui.dayPills.append(skel);
    }
    return;
  }
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
    if (occupancy >= 80) button.classList.add("occ-high");
    else if (occupancy >= 40) button.classList.add("occ-medium");
    else if (occupancy > 0) button.classList.add("occ-low");
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

function userForBooking(booking) {
  const email = String(booking?.email || "").toLowerCase();
  const uid = String(booking?.bookedForUid || "").trim();
  return (
    state.users.find((candidate) => uid && candidate.uid === uid) ||
    state.users.find((candidate) => email && candidate.email === email) ||
    null
  );
}

function renderParking() {
  const adminLike = isAdminLike();

  if (!state.spotsReady) {
    ui.spotsGrid.textContent = "";
    for (let i = 0; i < 8; i++) {
      const skel = document.createElement("div");
      skel.className = "skeleton skeleton-spot";
      ui.spotsGrid.append(skel);
    }
    return;
  }

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

  const searchQuery = (ui.spotSearch?.value || "").trim().toLowerCase();

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
    if (stateName === "booked") cell.classList.add("admin-clickable");
    cell.disabled = stateName === "blocked";

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

    if (stateName === "booked" && leadBooking) {
      const owner = document.createElement("div");
      if (adminLike) {
        owner.className = "spot-cell-booking-owner";
        owner.textContent = bookingDisplayName(leadBooking);
      } else {
        const isOwn = leadBooking.bookedForUid === state.user?.uid ||
          (leadBooking.email && leadBooking.email === state.profile?.email?.toLowerCase());
        if (isOwn) {
          owner.className = "spot-cell-booking-owner yours";
          owner.textContent = "YOURS";
        }
      }
      if (owner.textContent) cell.append(owner);
    }

    if (isSelectedFree) {
      const check = document.createElement("span");
      check.className = "spot-cell-check";
      check.textContent = "✓";
      cell.append(check);
    }

    if (searchQuery) {
      const spotNum = String(extractSpotNumber(spot.label)).toLowerCase();
      if (!spotNum.includes(searchQuery)) {
        cell.classList.add("search-hidden");
      } else {
        cell.classList.add("search-match");
      }
    }

    if (stateName === "free") {
      cell.addEventListener("click", () => {
        setSelectedSpot(spot.label);
        renderParking();
        syncBookUiState();
        scrollBookingFormIntoView();
      });
    } else if (stateName === "booked") {
      cell.addEventListener("click", () => {
        state.selectedAdminSpotLabel = spot.label;
        setSelectedSpot("");
        renderParking();
        renderAdminSpotInspector();
        openSpotDetailsModal(spot.label);
      });
    }

    ui.spotsGrid.append(cell);
  }

  ui.selectedSpotDisplay.value = state.selectedSpotLabel ? `Spot ${extractSpotNumber(state.selectedSpotLabel)}` : "";
  syncBookUiState();
  renderAdminSpotInspector();
  updateAdminTodayBar();
}

function renderMyBookings() {
  ui.myBookingsList.textContent = "";
  const adminLike = isAdminLike();
  const source = adminLike ? state.allBookings : state.myBookings;
  const now = new Date();
  const isPast = state.bookingsFilter === "past";

  const bookings = source
    .slice()
    .sort((a, b) => {
      const diff = a.bookingDate.getTime() - b.bookingDate.getTime();
      return isPast ? -diff : diff;
    })
    .filter((b) => isPast
      ? bookingEndDate(b.bookingDate, b.toTime) < now
      : bookingEndDate(b.bookingDate, b.toTime) >= now
    );

  if (!bookings.length) {
    const empty = document.createElement("div");
    empty.className = "empty-state";
    empty.innerHTML = isPast
      ? `<span class="empty-state-icon">🗓️</span><p>No past bookings yet.</p>`
      : `<span class="empty-state-icon">🅿️</span><p>No upcoming bookings.</p><p class="muted">Go to the Parking tab to book a spot.</p>`;
    ui.myBookingsList.append(empty);
    renderHomeHero();
    return;
  }

  if (adminLike && !isPast) {
    const bulkBar = document.createElement("div");
    bulkBar.className = "bulk-bar";
    const selectAll = document.createElement("input");
    selectAll.type = "checkbox";
    selectAll.id = "bulkSelectAll";
    selectAll.className = "bulk-checkbox";
    const selectLabel = document.createElement("label");
    selectLabel.htmlFor = "bulkSelectAll";
    selectLabel.textContent = "Select all";
    const bulkCancel = document.createElement("button");
    bulkCancel.type = "button";
    bulkCancel.className = "btn danger small bulk-cancel-btn hidden";
    bulkCancel.textContent = "Cancel selected";
    bulkCancel.addEventListener("click", async () => {
      if (!state.bulkSelectedIds.size) return;
      const count = state.bulkSelectedIds.size;
      if (!window.confirm(`Cancel ${count} booking${count > 1 ? "s" : ""}?`)) return;
      const toCancel = bookings.filter((b) => state.bulkSelectedIds.has(b.id));
      for (const b of toCancel) await cancelBooking(b, false);
      state.bulkSelectedIds.clear();
      renderMyBookings();
    });
    selectAll.addEventListener("change", () => {
      bookings.forEach((b) => {
        if (selectAll.checked) state.bulkSelectedIds.add(b.id);
        else state.bulkSelectedIds.delete(b.id);
      });
      bulkCancel.classList.toggle("hidden", state.bulkSelectedIds.size === 0);
      ui.myBookingsList.querySelectorAll(".booking-checkbox").forEach((cb) => { cb.checked = selectAll.checked; });
    });
    bulkBar.append(selectAll, selectLabel, bulkCancel);
    ui.myBookingsList.append(bulkBar);
  }

  for (const booking of bookings) {
    if (adminLike) {
      const row = document.createElement("article");
      row.className = "admin-booking-row";

      if (!isPast) {
        const cb = document.createElement("input");
        cb.type = "checkbox";
        cb.className = "booking-checkbox bulk-checkbox";
        cb.checked = state.bulkSelectedIds.has(booking.id);
        cb.addEventListener("change", () => {
          if (cb.checked) state.bulkSelectedIds.add(booking.id);
          else state.bulkSelectedIds.delete(booking.id);
          const bulkCancel = ui.myBookingsList.querySelector(".bulk-cancel-btn");
          if (bulkCancel) bulkCancel.classList.toggle("hidden", state.bulkSelectedIds.size === 0);
        });
        row.append(cb);
      }

      const main = document.createElement("div");
      main.className = "admin-booking-main";
      const title = document.createElement("p");
      title.className = "admin-booking-title";
      title.textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(booking.bookingDate)} · ${bookingDisplayName(booking)}`;
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
      actions.append(calendar);
      if (!isPast) {
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
        actions.append(edit, cancel);
      }

      row.append(main, actions);
      ui.myBookingsList.append(row);
      continue;
    }

    const node = ui.bookingTemplate.content.firstElementChild.cloneNode(true);
    node.querySelector(".title").textContent = `Spot ${extractSpotNumber(booking.spot)} · ${formatLongDate(booking.bookingDate)}`;
    node.querySelector(".meta").textContent = `${booking.fromTime} – ${booking.toTime}`;
    const calendarButton = node.querySelector(".calendar-btn");
    const cancelBtn = node.querySelector(".cancel-btn");
    calendarButton?.addEventListener("click", () => downloadCalendarForBooking(booking));
    if (isPast) {
      if (cancelBtn) cancelBtn.remove();
      const rebook = document.createElement("button");
      rebook.type = "button";
      rebook.className = "btn subtle rebook-btn";
      rebook.textContent = "Book again";
      rebook.addEventListener("click", () => {
        switchTab("parking");
        setSelectedSpot(booking.spot);
      });
      node.querySelector(".booking-row-actions")?.append(rebook);
    } else {
      cancelBtn?.addEventListener("click", () => cancelBooking(booking));
    }

    // Populate expandable detail section
    const detail = node.querySelector(".booking-row-detail");
    if (detail) {
      const inner = document.createElement("div");
      inner.className = "booking-row-detail-inner";
      const spotBadge = document.createElement("div");
      spotBadge.className = "booking-detail-spot";
      spotBadge.textContent = extractSpotNumber(booking.spot);
      const info = document.createElement("div");
      info.className = "booking-detail-info";
      const dateEl = document.createElement("strong");
      dateEl.textContent = formatLongDate(booking.bookingDate);
      const timeEl = document.createElement("span");
      timeEl.textContent = `${booking.fromTime} – ${booking.toTime}`;
      info.append(dateEl, timeEl);
      if (booking.user) {
        const personEl = document.createElement("span");
        personEl.textContent = booking.user;
        info.append(personEl);
      }
      inner.append(spotBadge, info);
      detail.append(inner);
    }

    // Tap the summary row (not buttons) to expand detail
    node.querySelector(".booking-row-summary")?.addEventListener("click", (e) => {
      if (e.target.closest("button")) return;
      node.classList.toggle("expanded");
    });

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

function openSpotDetailsModal(spotLabel) {
  if (!ui.spotDetailsModal) return;
  const bookings = bookingsForSpotOnSelectedDay(spotLabel);
  ui.spotDetailsTitle.textContent = `Spot ${extractSpotNumber(spotLabel)}`;
  ui.spotDetailsMeta.textContent = `${formatLongDate(dayStart(state.selectedDate))} · ${
    bookings.length ? `${bookings.length} active booking${bookings.length === 1 ? "" : "s"}` : "No active bookings"
  }`;
  ui.spotDetailsList.textContent = "";

  if (!bookings.length) {
    ui.spotDetailsList.append(textRow("No booking is active for this spot on the selected day."));
  }

  for (const booking of bookings) {
    const row = document.createElement("article");
    row.className = "spot-detail-row";

    const owner = userForBooking(booking);
    const avatar = document.createElement("div");
    avatar.className = "spot-detail-avatar";
    const presetID = owner?.vehicleMiniaturePresetID || "";
    const image = vehicleImageElement(presetID, owner?.carDescription || "");
    if (image) {
      avatar.append(image);
    } else {
      avatar.textContent = initials(bookingDisplayName(booking));
    }

    const main = document.createElement("div");
    main.className = "spot-detail-main";
    const title = document.createElement("p");
    title.className = "spot-detail-title";
    title.textContent = isAdminLike() ? bookingDisplayName(booking) : "Booked";
    const meta = document.createElement("p");
    meta.className = "spot-detail-meta";
    const vehicleText = owner?.carDescription ? ` · ${owner.carDescription}` : "";
    const plateText = owner?.registrationPlate ? ` · ${owner.registrationPlate}` : "";
    meta.textContent = `${booking.fromTime} - ${booking.toTime}${isAdminLike() ? `${vehicleText}${plateText}` : ""}`;
    main.append(title, meta);

    row.append(avatar, main);

    if (isAdminLike()) {
      const actions = document.createElement("div");
      actions.className = "spot-detail-actions";
      const calendar = document.createElement("button");
      calendar.type = "button";
      calendar.className = "btn subtle small";
      calendar.textContent = "Calendar";
      calendar.addEventListener("click", () => downloadCalendarForBooking(booking));
      const edit = document.createElement("button");
      edit.type = "button";
      edit.className = "btn subtle small";
      edit.textContent = "Edit";
      edit.addEventListener("click", () => {
        closeSpotDetailsModal();
        openBookingEditModal(booking);
      });
      const cancel = document.createElement("button");
      cancel.type = "button";
      cancel.className = "btn danger small";
      cancel.textContent = "Cancel";
      cancel.addEventListener("click", () => cancelBooking(booking));
      actions.append(calendar, edit, cancel);
      row.append(actions);
    }

    ui.spotDetailsList.append(row);
  }

  ui.spotDetailsModal.classList.remove("hidden");
  ui.spotDetailsModal.setAttribute("aria-hidden", "false");
}

function closeSpotDetailsModal() {
  if (!ui.spotDetailsModal) return;
  ui.spotDetailsModal.classList.add("hidden");
  ui.spotDetailsModal.setAttribute("aria-hidden", "true");
}

function showConfirm({ title, message, acceptLabel = "Confirm", cancelLabel = "Cancel" }) {
  if (!ui.confirmModal) return Promise.resolve(window.confirm(message));
  ui.confirmTitle.textContent = title || "Confirm Action";
  ui.confirmMessage.textContent = message || "";
  ui.confirmAccept.textContent = acceptLabel;
  ui.confirmCancel.textContent = cancelLabel;
  ui.confirmModal.classList.remove("hidden");
  ui.confirmModal.setAttribute("aria-hidden", "false");
  return new Promise((resolve) => {
    state.confirmResolver = resolve;
  });
}

function resolveConfirm(value) {
  if (!ui.confirmModal || !state.confirmResolver) return;
  const resolve = state.confirmResolver;
  state.confirmResolver = null;
  ui.confirmModal.classList.add("hidden");
  ui.confirmModal.setAttribute("aria-hidden", "true");
  resolve(Boolean(value));
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

async function cancelBooking(booking, confirmFirst = true) {
  if (!state.user || !state.profile) return;
  if (confirmFirst) {
    const ok = await showConfirm({
      title: "Cancel Booking",
      message: `Cancel spot ${extractSpotNumber(booking.spot)} on ${formatLongDate(booking.bookingDate)}?`,
      acceptLabel: "Cancel Booking",
      cancelLabel: "Keep Booking",
    });
    if (!ok) return;
  }

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
    if (confirmFirst) closeSpotDetailsModal();
  } catch (err) {
    showToast(err?.message || "Cancel failed.", "error");
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
  syncCarDescriptionField();
  const carDescription = ui.carInput.value.trim();
  const vehicleMiniaturePresetID = state.selectedVehiclePresetID || "";
  const carColor = presetColorLabel(vehicleMiniaturePresetID);

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
      carColor,
      carType: "",
      vehicleMiniaturePresetID,
    });
    state.profile = {
      ...state.profile,
      displayName,
      preferredVocative,
      registrationPlate,
      carDescription,
      carColor,
      carType: "",
      vehicleMiniaturePresetID,
    };
    renderGreeting();
    state.profileDirty = false;
    showToast("Profile saved.");
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
  hydrateVehicleSelection();
  state.profileDirty = false;
}

function hydrateVehicleSelection() {
  const parsed = parseVehicleDescription(state.profile?.carDescription || "");
  const presetID = state.profile?.vehicleMiniaturePresetID || "";
  const preset = presetByID(presetID);
  state.selectedVehicleMake = preset?.make || parsed.make || CAR_MAKES[0] || "";
  renderMakeButton();
  state.selectedVehicleModel = preset?.models?.[0] || parsed.model || firstModelForMake(state.selectedVehicleMake);
  populateVehicleModelSelect();
  ui.vehicleModelSelect.value = state.selectedVehicleModel;
  state.selectedVehiclePresetID = presetMatchesVehicle(presetID, state.selectedVehicleMake, state.selectedVehicleModel)
    ? presetID
    : "";
  syncCarDescriptionField();
  renderVehiclePreview();
}

function renderMakeButton() {
  if (!ui.vehicleMakeLabel) return;
  ui.vehicleMakeLabel.textContent = state.selectedVehicleMake || CAR_MAKES[0] || "";
}

function populateVehicleModelSelect() {
  if (!ui.vehicleModelSelect) return;
  const make = state.selectedVehicleMake;
  const previous = ui.vehicleModelSelect.value || state.selectedVehicleModel;
  const models = MODELS_BY_MAKE[make] || [];
  ui.vehicleModelSelect.textContent = "";
  for (const model of models) {
    const option = document.createElement("option");
    option.value = model;
    option.textContent = model;
    ui.vehicleModelSelect.append(option);
  }
  if (models.includes(previous)) ui.vehicleModelSelect.value = previous;
  else ui.vehicleModelSelect.value = models[0] || "";
}

function renderVehiclePreview() {
  if (!ui.vehiclePreview) return;
  const make = state.selectedVehicleMake || "";
  const model = state.selectedVehicleModel || ui.vehicleModelSelect?.value || "";
  const preset = presetByID(state.selectedVehiclePresetID);
  const title = preset?.title || [make, model].filter(Boolean).join(" ");
  const logo = makerLogoElement(make);
  const car = vehicleImageElement(state.selectedVehiclePresetID, title);

  ui.vehiclePreview.textContent = "";
  const logoWrap = document.createElement("div");
  logoWrap.className = "vehicle-preview-logo";
  if (logo) logoWrap.append(logo);
  else logoWrap.textContent = initials(make || "EL");

  const copy = document.createElement("div");
  copy.className = "vehicle-preview-copy";
  const titleNode = document.createElement("strong");
  titleNode.textContent = title || "Vehicle";
  const meta = document.createElement("span");
  meta.textContent = preset ? "Specific icon selected" : "Automatic icon";
  copy.append(titleNode, meta);

  const carWrap = document.createElement("div");
  carWrap.className = "vehicle-preview-car";
  if (car) carWrap.append(car);
  else carWrap.textContent = "Choose icon";

  ui.vehiclePreview.append(logoWrap, copy, carWrap);
  if (ui.vehicleIconLabel) ui.vehicleIconLabel.textContent = preset?.title || "Automatic";
}

function openMakePicker() {
  if (!ui.makePickerModal) return;
  renderMakePickerOptions();
  ui.makePickerModal.classList.remove("hidden");
  ui.makePickerModal.setAttribute("aria-hidden", "false");
}

function closeMakePicker() {
  if (!ui.makePickerModal) return;
  ui.makePickerModal.classList.add("hidden");
  ui.makePickerModal.setAttribute("aria-hidden", "true");
}

function renderMakePickerOptions() {
  if (!ui.makePickerList) return;
  ui.makePickerList.textContent = "";
  for (const make of CAR_MAKES) {
    const row = document.createElement("button");
    row.type = "button";
    row.className = "make-picker-row";
    row.classList.toggle("selected", state.selectedVehicleMake === make);
    const media = document.createElement("span");
    media.className = "make-picker-media";
    const logo = makerLogoElement(make);
    if (logo) media.append(logo);
    else media.textContent = initials(make);
    const name = document.createElement("span");
    name.className = "make-picker-name";
    name.textContent = make;
    const check = document.createElement("span");
    check.className = "vehicle-picker-check";
    check.textContent = state.selectedVehicleMake === make ? "✓" : "";
    row.append(media, name, check);
    row.addEventListener("click", () => {
      state.selectedVehicleMake = make;
      renderMakeButton();
      populateVehicleModelSelect();
      state.selectedVehicleModel = ui.vehicleModelSelect?.value || "";
      if (!presetMatchesVehicle(state.selectedVehiclePresetID, state.selectedVehicleMake, state.selectedVehicleModel)) {
        state.selectedVehiclePresetID = "";
      }
      syncCarDescriptionField();
      renderVehiclePreview();
      closeMakePicker();
    });
    ui.makePickerList.append(row);
  }
}

function openVehiclePicker() {
  if (!ui.vehiclePickerModal) return;
  const make = state.selectedVehicleMake;
  const model = ui.vehicleModelSelect?.value || state.selectedVehicleModel;
  ui.vehiclePickerTitle.textContent = "Choose Vehicle Icon";
  ui.vehiclePickerMeta.textContent = [make, model].filter(Boolean).join(" · ");
  renderVehiclePickerOptions();
  ui.vehiclePickerModal.classList.remove("hidden");
  ui.vehiclePickerModal.setAttribute("aria-hidden", "false");
}

function closeVehiclePicker() {
  if (!ui.vehiclePickerModal) return;
  ui.vehiclePickerModal.classList.add("hidden");
  ui.vehiclePickerModal.setAttribute("aria-hidden", "true");
}

function renderVehiclePickerOptions() {
  if (!ui.vehiclePickerList) return;
  const make = state.selectedVehicleMake;
  const model = ui.vehicleModelSelect?.value || state.selectedVehicleModel;
  const options = presetsForVehicle(make, model);
  ui.vehiclePickerList.textContent = "";

  const automatic = document.createElement("button");
  automatic.type = "button";
  automatic.className = "vehicle-picker-row";
  automatic.innerHTML = `<span class="vehicle-picker-auto">Auto</span><span><strong>Automatic</strong><small>Use best match from make and model</small></span>`;
  automatic.addEventListener("click", () => {
    state.selectedVehiclePresetID = "";
    renderVehiclePreview();
    closeVehiclePicker();
  });
  ui.vehiclePickerList.append(automatic);

  for (const option of options) {
    const row = document.createElement("button");
    row.type = "button";
    row.className = "vehicle-picker-row";
    row.classList.toggle("selected", state.selectedVehiclePresetID === option.id);
    const image = vehicleImageElement(option.id, option.title);
    const media = document.createElement("span");
    media.className = "vehicle-picker-media";
    if (image) media.append(image);
    const copy = document.createElement("span");
    copy.className = "vehicle-picker-copy";
    const title = document.createElement("strong");
    title.textContent = option.title;
    const meta = document.createElement("small");
    const logo = makerLogoElement(option.make);
    if (logo) {
      logo.className = "vehicle-picker-make-logo";
      meta.append(logo);
    }
    meta.append(option.make);
    copy.append(title, meta);
    const check = document.createElement("span");
    check.className = "vehicle-picker-check";
    check.textContent = state.selectedVehiclePresetID === option.id ? "✓" : "";
    row.append(media, copy, check);
    row.addEventListener("click", () => {
      state.selectedVehiclePresetID = option.id;
      renderVehiclePreview();
      closeVehiclePicker();
    });
    ui.vehiclePickerList.append(row);
  }

  if (!options.length) {
    const empty = document.createElement("p");
    empty.className = "muted";
    empty.textContent = "No specific miniature is available for this make and model yet.";
    ui.vehiclePickerList.append(empty);
  }
}

function syncCarDescriptionField() {
  if (!ui.carInput) return;
  const make = state.selectedVehicleMake || "";
  const model = ui.vehicleModelSelect?.value || state.selectedVehicleModel || "";
  ui.carInput.value = [make, model].filter(Boolean).join(" ");
}

function parseVehicleDescription(description) {
  const text = String(description || "").trim();
  if (!text) return { make: "", model: "" };
  const normalized = normalizeSearchText(text);
  const make = CAR_MAKES.find((candidate) => normalized.startsWith(normalizeSearchText(candidate))) || "";
  if (!make) return { make: "", model: text };
  const rest = text.slice(make.length).trim();
  const model =
    (MODELS_BY_MAKE[make] || []).find((candidate) => normalizeSearchText(rest) === normalizeSearchText(candidate)) ||
    rest ||
    firstModelForMake(make);
  return { make, model };
}

function firstModelForMake(make) {
  return (MODELS_BY_MAKE[make] || [])[0] || "";
}

function presetsForVehicle(make, model) {
  const normalizedMake = normalizeSearchText(make);
  const normalizedModel = normalizeSearchText(model);
  return VEHICLE_PRESETS.filter((preset) => {
    if (normalizeSearchText(preset.make) !== normalizedMake) return false;
    if (!normalizedModel) return true;
    return preset.models.some((candidate) => {
      const normalizedCandidate = normalizeSearchText(candidate);
      return normalizedCandidate === normalizedModel || normalizedModel.includes(normalizedCandidate) || normalizedCandidate.includes(normalizedModel);
    });
  });
}

function presetMatchesVehicle(presetID, make, model) {
  if (!presetID) return false;
  return presetsForVehicle(make, model).some((preset) => preset.id === presetID);
}

function presetByID(id) {
  return VEHICLE_PRESETS.find((preset) => preset.id === id) || null;
}

function presetColorLabel(id) {
  const preset = presetByID(id);
  const parts = String(preset?.title || "").split("·");
  return parts[1]?.trim() || "";
}

function makerLogoElement(make) {
  const asset = MAKER_LOGOS[make];
  if (!asset) return null;
  const img = document.createElement("img");
  img.src = `./makers/${asset}.png`;
  img.alt = `${make} logo`;
  img.loading = "lazy";
  img.decoding = "async";
  return img;
}

function vehicleImageElement(presetID, fallbackDescription) {
  const preset = presetByID(presetID);
  const asset = preset?.asset || automaticVehicleAsset(fallbackDescription);
  if (!asset) return null;
  const img = document.createElement("img");
  img.src = `./vehicles/${asset}.png`;
  img.alt = preset?.title || fallbackDescription || "Vehicle";
  img.loading = "lazy";
  img.decoding = "async";
  return img;
}

function automaticVehicleAsset(description) {
  const text = normalizeSearchText(description);
  if (text.includes("volvo") && text.includes("ex30")) return "vehicle_mini_volvo_ex30_moss_yellow_yellow";
  if (text.includes("tesla") && text.includes("model 3")) return "vehicle_mini_tesla_model3";
  if (text.includes("octavia")) return "vehicle_mini_skoda_octavia_combi_style";
  if (text.includes("kodiaq")) return "vehicle_mini_skoda_kodiaq";
  if (text.includes("karoq")) return "vehicle_mini_skoda_karoq_style";
  if (text.includes("superb")) return "vehicle_mini_superb_white";
  if (text.includes("tiguan")) return "vehicle_mini_vw_tiguan";
  if (text.includes("golf")) return "vehicle_mini_vw_golf_variant";
  if (text.includes("bmw") && text.includes("i4")) return "vehicle_mini_bmw_i4";
  if (text.includes("bmw")) return "vehicle_mini_bmw_3_black";
  if (text.includes("audi")) return "vehicle_mini_audi_a4_avant_b9";
  if (text.includes("mercedes") && text.includes("eqa")) return "vehicle_mini_electric_crossover_silver";
  if (text.includes("mercedes") && text.includes("gla")) return "vehicle_mini_compact_suv_white";
  if (text.includes("mercedes")) return "vehicle_mini_mercedes_c220d_4matic";
  if (text.includes("audi") && text.includes("q4")) return "vehicle_mini_electric_crossover_silver";
  if (text.includes("caddy")) return "vehicle_mini_van_white";
  if (text.includes("mini")) return "vehicle_mini_mini_countryman_black";
  if (text.includes("subaru")) return "vehicle_mini_subaru_outback_brown";
  if (text.includes("hyundai") && text.includes("bayon")) return "vehicle_mini_hyundai_bayon_navy";
  return "vehicle_mini_generic_sedan_white";
}

function normalizeSearchText(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function initials(value) {
  const parts = String(value || "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2);
  return parts.map((part) => part[0]?.toUpperCase() || "").join("") || "EL";
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
  ui.finishView.classList.toggle("hidden", mode !== "finish");
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
  if (!ui.bookingSuccessModal) return;
  const spot = extractSpotNumber(spotLabel);
  const dateText = formatLongDate(bookingDate);

  if (ui.bookingSuccessSummary) {
    ui.bookingSuccessSummary.textContent = "";
    const spotBox = document.createElement("div");
    spotBox.className = "success-spot-box";
    const spotNum = document.createElement("span");
    spotNum.className = "success-spot-number";
    spotNum.textContent = spot;
    const spotLabel2 = document.createElement("span");
    spotLabel2.className = "success-spot-label";
    spotLabel2.textContent = "Spot";
    spotBox.append(spotLabel2, spotNum);

    const info = document.createElement("div");
    info.className = "success-info";
    const dateLine = document.createElement("p");
    dateLine.textContent = dateText;
    const timeLine = document.createElement("p");
    timeLine.className = "muted";
    timeLine.textContent = `${fromTime} – ${toTime}`;
    info.append(dateLine, timeLine);

    const carImg = vehicleImageElement(state.selectedVehiclePresetID,
      [state.selectedVehicleMake, state.selectedVehicleModel].filter(Boolean).join(" "));
    if (carImg) {
      carImg.className = "success-car-img";
      ui.bookingSuccessSummary.append(spotBox, info, carImg);
    } else {
      ui.bookingSuccessSummary.append(spotBox, info);
    }
  }

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
  if (!createdAtMs) createdAtMs = Date.now();
  return {
    id,
    title: String(data.title ?? ""),
    body: String(data.body ?? ""),
    emoji: String(data.emoji ?? "📣"),
    isActive: data.isActive !== false,
    isPinned: Boolean(data.isPinned),
    imageURL: String(data.imageURL ?? data.imageUrl ?? data.image ?? "").trim(),
    createdBy: String(data.createdBy ?? ""),
    createdAtMs,
  };
}

function parseInfoItem(id, data) {
  const createdAtRaw = data.createdAt;
  let createdAtMs = 0;
  if (createdAtRaw?.toDate) createdAtMs = createdAtRaw.toDate().getTime();
  else if (typeof createdAtRaw === "string" || typeof createdAtRaw === "number") {
    const parsed = new Date(createdAtRaw);
    if (!Number.isNaN(parsed.getTime())) createdAtMs = parsed.getTime();
  }
  return {
    id,
    icon: String(data.icon ?? "info.circle.fill"),
    title: String(data.title ?? ""),
    body: String(data.body ?? ""),
    imageURL: String(data.imageURL ?? ""),
    details: String(data.details ?? ""),
    linkTitle: String(data.linkTitle ?? ""),
    linkURL: String(data.linkURL ?? ""),
    sortOrder: Number(data.sortOrder ?? 0),
    createdAtMs,
  };
}

function parseUser(data, docId = "") {
  return {
    uid: String(data.uid ?? docId),
    email: String(data.email ?? "").toLowerCase(),
    displayName: String(data.displayName ?? ""),
    role: String(data.role ?? "user"),
    status: String(data.status ?? "pending"),
    registrationPlate: String(data.registrationPlate ?? ""),
    carDescription: String(data.carDescription ?? ""),
    needsFinishRegistration: Boolean(data.needsFinishRegistration ?? false),
    carType: String(data.carType ?? ""),
    carColor: String(data.carColor ?? ""),
    vehicleMiniaturePresetID: String(data.vehicleMiniaturePresetID ?? ""),
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

function titleCase(value) {
  const text = String(value || "");
  return text ? text.charAt(0).toUpperCase() + text.slice(1) : "";
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
