//
//  AdminUsersView.swift
//  EL PARKING APP
//
//  Admin panel: view all users, activate pending ones, manage roles.
//  Supports bulk selection for activating multiple pending users at once.
//

import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject var authManager:   AuthManager
    @EnvironmentObject var bookingManager: BookingManager
    @ObservedObject private var lang = LanguageManager.shared
    @ObservedObject private var vehicleCatalog = VehicleCatalogStore.shared

    @AppStorage("adminUsersLayoutGrid") private var useGridLayout = false
    @State private var selectedFilter: UserStatus? = nil
    @State private var selectedCompanyFilter: CompanyBadge? = nil
    @State private var isLoading       = false

    init(initialFilter: UserStatus? = nil) {
        _selectedFilter = State(initialValue: initialFilter)
    }
    @State private var userToActivate: AppUser?
    @State private var userToQuickReject: AppUser?
    @State private var showQuickRejectAlert = false
    @State private var userToEditVehicle: AppUser?
    @State private var editPlate        = ""
    @State private var editCar          = ""
    @State private var editCarType      = ""
    @State private var editColor        = AppConfig.carColors.first?.hex ?? ""
    @State private var editPresetID     = ""
    @State private var editSelectedMake = ""
    @State private var editSelectedModel = ""
    @State private var showEditVehiclePresetSheet = false
    @State private var showEditVehicleColorPicker = false
    @State private var userToSuspend: AppUser?
    @State private var showSuspendAlert  = false
    @State private var selectedRole: UserRole = .user
    @State private var searchText = ""
    @State private var rejectionReasonText = ""
    @State private var userToDelete: AppUser?
    @State private var showDeleteAlert = false
    // Strike system
    @State private var userToStrike: AppUser?
    @State private var strikeReason = ""
    @State private var removeStrikeReason = ""
    @State private var isAssigningStrike = false

    // Approve animation
    @State private var recentlyActivatedUID: String?

    // Bulk selection
    @State private var isSelecting  = false
    @State private var selectedUIDs: Set<String> = []
    @State private var bulkRole: UserRole = .user
    @State private var isBulkActivating = false
    @State private var isBulkDeleting   = false
    @State private var tappedUserID: String?
    @State private var userDetailSheetUser: AppUser?

    // Admin password-reset
    @State private var userToResetPassword: AppUser?
    @State private var showResetPasswordAlert = false
    @State private var resetPasswordResultMessage = ""
    @State private var showResetPasswordResult = false

    // MARK: - Filtered Users

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredUsers: [AppUser] {
        var users = authManager.allUsers
        if let filter = selectedFilter { users = users.filter { $0.status == filter } }
        if let company = selectedCompanyFilter { users = users.filter { $0.companyBadge == company } }
        if !normalizedSearchQuery.isEmpty {
            users = users.filter {
                $0.displayName.lowercased().contains(normalizedSearchQuery) ||
                $0.email.lowercased().contains(normalizedSearchQuery) ||
                $0.registrationPlate.lowercased().contains(normalizedSearchQuery) ||
                $0.carDescription.lowercased().contains(normalizedSearchQuery) ||
                $0.carType.lowercased().contains(normalizedSearchQuery)
            }
        }
        return users.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var userCounts: (pending: Int, active: Int, suspended: Int) {
        authManager.allUsers.reduce(into: (0, 0, 0)) { result, user in
            if user.isPending { result.pending += 1 }
            if user.isActive { result.active += 1 }
            if user.isSuspended { result.suspended += 1 }
        }
    }

    private var companyCounts: (omega: Int, essilorLuxottica: Int, grandVision: Int) {
        authManager.allUsers.reduce(into: (0, 0, 0)) { result, user in
            switch user.companyBadge {
            case .omega: result.0 += 1
            case .essilorLuxottica: result.1 += 1
            case .grandVision: result.2 += 1
            case .none: break
            }
        }
    }

    private var pendingUsers: [AppUser] { filteredUsers.filter { $0.isPending } }
    private var pendingCount:   Int { userCounts.pending }
    private var activeCount:    Int { userCounts.active }
    private var suspendedCount: Int { userCounts.suspended }
    private var shouldShowLoadingSkeleton: Bool { isLoading && authManager.allUsers.isEmpty }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppConfig.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                searchBar
                filterPills.padding(.top, 8)

                if shouldShowLoadingSkeleton {
                    usersSkeletonList
                } else if filteredUsers.isEmpty {
                    emptyState
                } else {
                    userGrid
                }
                // Classic list layout (kept for reference):
                // } else {
                //     userList
                // }
            }

            // Bulk action bar (floats above content)
            if isSelecting && !selectedUIDs.isEmpty {
                bulkActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            }
            .animation(.standard, value: isSelecting)
            .animation(.standard, value: selectedUIDs.isEmpty)
            .navigationTitle(L10n.userManagement)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedFilter == .pending && !pendingUsers.isEmpty {
                        Button {
                            Haptics.impact(.rigid)
                            withAnimation(.standard) {
                                isSelecting.toggle()
                                if !isSelecting { selectedUIDs.removeAll() }
                            }
                        } label: {
                            Text(isSelecting ? L10n.done : L10n.select)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConfig.darkText)
                        }
                    }
                }
            }
            .sheet(item: $userToActivate) { user in
                activateSheet(user: user)
            }
            .sheet(item: $userDetailSheetUser) { user in
                userDetailSheet(user: user)
            }
            .sheet(item: $userToEditVehicle) { user in
                editVehicleSheet(user: user)
            }
            .sheet(item: $userToStrike) { user in
                strikeSheet(user: user)
            }
            .confirmationDialog(L10n.rejectUser, isPresented: $showQuickRejectAlert, titleVisibility: .visible) {
                Button(L10n.rejectUser, role: .destructive) {
                    if let user = userToQuickReject {
                        Task { await authManager.rejectUser(user, reason: L10n.lang == .czech ? "Žádost zamítnuta administrátorem." : "Registration rejected by administrator.") }
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                if let user = userToQuickReject {
                    Text("Reject \(user.displayName)'s registration request?")
                }
            }
            .confirmationDialog(L10n.suspendUser, isPresented: $showSuspendAlert, titleVisibility: .visible) {
                Button(L10n.suspend, role: .destructive) {
                    if let user = userToSuspend {
                        Task { await authManager.suspendUser(user) }
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                if let user = userToSuspend {
                    Text(L10n.suspendUserMsg(user.displayName))
                }
            }
            .confirmationDialog(L10n.deleteUser, isPresented: $showDeleteAlert, titleVisibility: .visible) {
                Button(L10n.deleteUser, role: .destructive) {
                    if let user = userToDelete {
                        Haptics.destructive()
                        Task { await authManager.adminDeleteUser(user) }
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                if let user = userToDelete {
                    Text(L10n.confirmDeleteUser(user.displayName))
                }
            }
            .confirmationDialog(L10n.adminResetPassword, isPresented: $showResetPasswordAlert, titleVisibility: .visible) {
                Button(L10n.sendResetLink) {
                    if let user = userToResetPassword {
                        let email = user.email
                        Task {
                            let ok = await authManager.adminSendPasswordReset(to: email)
                            resetPasswordResultMessage = ok ? L10n.adminResetPasswordSent : L10n.adminResetPasswordFail
                            showResetPasswordResult = true
                        }
                    }
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                if let user = userToResetPassword {
                    Text(L10n.adminResetPasswordConfirm(user.email))
                }
            }
            .alert(L10n.adminResetPassword, isPresented: $showResetPasswordResult) {
                Button(L10n.ok, role: .cancel) {}
            } message: {
                Text(resetPasswordResultMessage)
            }
            .task {
                vehicleCatalog.ensureLoaded()
                await refresh()
            }
            .onChange(of: vehicleCatalog.revision) {
                syncEditVehicleMakeModelFromDescription()
            }
            .onChange(of: selectedFilter) {
                isSelecting = false
                selectedUIDs.removeAll()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppConfig.subtleGray)
            TextField(L10n.searchUsers, text: $searchText)
                .foregroundStyle(AppConfig.darkText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(AppConfig.subtleGray)
                }
                .buttonStyle(ScaleButtonStyle())
                .tint(AppConfig.darkText)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .padding(.horizontal).padding(.top, 4)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                statusFilterMenu
                    .frame(maxWidth: .infinity)
                companyFilterMenu
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private func filterPill(label: String, count: Int, filter: UserStatus?) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            Haptics.selection()
            withAnimation(.standard) { selectedFilter = filter }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .fontWeight(isSelected ? .semibold : .medium)
                if count > 0 {
                    PillCountBadge(count: count, emphasized: isSelected)
                }
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .capsulePillChrome(isSelected: isSelected)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var companyFilterMenu: some View {
        Menu {
            Button {
                Haptics.selection()
                withAnimation(.standard) { selectedCompanyFilter = nil }
            } label: {
                HStack {
                    Text(L10n.all)
                    if selectedCompanyFilter == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            ForEach(CompanyBadge.sortedCases.filter { $0 != .none }, id: \.rawValue) { badge in
                Button {
                    Haptics.selection()
                    withAnimation(.standard) { selectedCompanyFilter = badge }
                } label: {
                    HStack {
                        Text(companyBadgeLabel(badge))
                        if selectedCompanyFilter == badge {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.footnote.weight(.semibold))
                Text("Company: \(selectedCompanyChipLabel)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if selectedCompanyFilter != nil {
                    PillCountBadge(count: selectedCompanyCount)
                }
            }
            .foregroundStyle(AppConfig.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
            .capsulePillChrome()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var statusFilterMenu: some View {
        Menu {
            Button {
                Haptics.selection()
                withAnimation(.standard) { selectedFilter = nil }
            } label: {
                HStack {
                    Text(statusAllUsersLabel)
                    if selectedFilter == nil {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                Haptics.selection()
                withAnimation(.standard) { selectedFilter = .pending }
            } label: {
                HStack {
                    Text(statusPendingUsersLabel)
                    if selectedFilter == .pending {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                Haptics.selection()
                withAnimation(.standard) { selectedFilter = .active }
            } label: {
                HStack {
                    Text(statusActiveUsersLabel)
                    if selectedFilter == .active {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }

            Button {
                Haptics.selection()
                withAnimation(.standard) { selectedFilter = .suspended }
            } label: {
                HStack {
                    Text(statusSuspendedUsersLabel)
                    if selectedFilter == .suspended {
                        Spacer()
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.footnote.weight(.semibold))
                Text("Status: \(selectedStatusChipLabel)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if selectedFilter != nil {
                    PillCountBadge(count: selectedStatusCount)
                }
            }
            .foregroundStyle(AppConfig.darkText)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 46)
            .contentShape(Rectangle())
            .capsulePillChrome()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var selectedStatusFilterLabel: String {
        switch selectedFilter {
        case .none: return statusAllUsersLabel
        case .some(.pending): return statusPendingUsersLabel
        case .some(.active): return statusActiveUsersLabel
        case .some(.suspended): return statusSuspendedUsersLabel
        }
    }

    private var selectedStatusCount: Int {
        switch selectedFilter {
        case .none: return authManager.allUsers.count
        case .some(.pending): return pendingCount
        case .some(.active): return activeCount
        case .some(.suspended): return suspendedCount
        }
    }

    private var selectedStatusChipLabel: String {
        switch selectedFilter {
        case .none: return L10n.all
        case .some(.pending): return L10n.pending
        case .some(.active): return L10n.activeFilter
        case .some(.suspended): return L10n.suspended
        }
    }

    private var selectedCompanyFilterLabel: String {
        switch selectedCompanyFilter {
        case nil:
            return L10n.all
        case .some(.omega):
            return L10n.omegaLabel
        case .some(.essilorLuxottica):
            return L10n.essilorLuxotticaLabel
        case .some(.grandVision):
            return L10n.grandVisionLabel
        case .some(.none):
            return L10n.noneLabel
        }
    }

    private var selectedCompanyCount: Int {
        switch selectedCompanyFilter {
        case nil:
            return authManager.allUsers.count
        case .some(.omega):
            return companyCounts.omega
        case .some(.essilorLuxottica):
            return companyCounts.essilorLuxottica
        case .some(.grandVision):
            return companyCounts.grandVision
        case .some(.none):
            return authManager.allUsers.filter { $0.companyBadge == .none }.count
        }
    }

    private var selectedCompanyChipLabel: String {
        switch selectedCompanyFilter {
        case nil: return L10n.all
        case .some(.omega): return "Omega"
        case .some(.essilorLuxottica): return "EL"
        case .some(.grandVision): return "GV"
        case .some(.none): return L10n.noneLabel
        }
    }

    private var statusAllUsersLabel: String {
        L10n.lang == .czech ? "Všichni uživatelé" : "All users"
    }

    private var statusPendingUsersLabel: String {
        L10n.lang == .czech ? "Čekající uživatelé" : "Pending users"
    }

    private var statusActiveUsersLabel: String {
        L10n.lang == .czech ? "Aktivní uživatelé" : "Active users"
    }

    private var statusSuspendedUsersLabel: String {
        L10n.lang == .czech ? "Pozastavení uživatelé" : "Suspended users"
    }

    // MARK: - User List

    private var userList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                // Select All row (only when selecting in pending mode)
                if isSelecting && selectedFilter == .pending {
                    selectAllRow
                }
                ForEach(filteredUsers) { user in
                    Group {
                        if isSelecting && user.isPending {
                            userRow(user)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.standard) { tappedUserID = user.uid }
                                    withAnimation(.standard) {
                                        if selectedUIDs.contains(user.uid) {
                                            selectedUIDs.remove(user.uid)
                                        } else {
                                            selectedUIDs.insert(user.uid)
                                        }
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 120_000_000)
                                        await MainActor.run {
                                            withAnimation(.standard) {
                                                if tappedUserID == user.uid { tappedUserID = nil }
                                            }
                                        }
                                    }
                                }
                        } else {
                            userRow(user)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    guard !isSelecting else { return }
                                    userDetailSheetUser = user
                                }
                        }
                    }
                    .scaleEffect(tappedUserID == user.uid ? 0.987 : 1)
                    .opacity(tappedUserID == user.uid ? 0.97 : 1)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal:   .opacity.combined(with: .scale(scale: 0.96))
                    ))
                }
            }
            .animation(.standard, value: filteredUsers.count)
            .padding(.horizontal)
            .padding(.bottom, isSelecting && !selectedUIDs.isEmpty ? 120 : 100)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable {
            await refresh()
            Haptics.refreshCompleted()
        }
    }

    // MARK: - User Grid

    private var userGrid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(filteredUsers) { user in
                    userGridCard(user)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.selection()
                            userDetailSheetUser = user
                        }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable {
            await refresh()
            Haptics.refreshCompleted()
        }
    }

    private func userGridCard(_ user: AppUser) -> some View {
        let isMe = user.uid == authManager.currentUser?.uid
        let hasSpecificMini = VehicleMiniatureView.hasSpecificMiniature(
            carType: user.carType,
            description: user.carDescription,
            presetID: user.vehicleMiniaturePresetID.isEmpty ? nil : user.vehicleMiniaturePresetID
        )

        return VStack(spacing: 10) {
            if hasSpecificMini {
                VehicleMiniatureView(
                    carType: user.carType,
                    colorHex: user.carColor,
                    description: user.carDescription,
                    presetID: user.vehicleMiniaturePresetID.isEmpty ? nil : user.vehicleMiniaturePresetID
                )
                .frame(width: 100, height: 56)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                UserAvatarView(user: user, size: 56, showStroke: true)
                    .padding(.top, 4)
            }

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text(user.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppConfig.darkText)
                        .lineLimit(1)
                    if isMe {
                        Text(L10n.you)
                            .font(.system(size: 8, weight: .bold)).tracking(0.8)
                            .foregroundStyle(AppConfig.darkText)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(AppConfig.surfaceHigh)
                            .clipShape(Capsule())
                    }
                }

                if !user.registrationPlate.isEmpty {
                    Text(user.registrationPlate)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                }

                CompanyBadgeView(badge: user.companyBadge, compact: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 4) {
                gridStatusDot(user.status)
                gridRoleBadge(user.role)
                if user.strikes > 0 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppConfig.warning)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .cardShadow()
    }

    private func gridStatusDot(_ status: UserStatus) -> some View {
        let color: Color = {
            switch status {
            case .pending:   return AppConfig.warning
            case .active:    return AppConfig.activeGreen
            case .suspended: return AppConfig.spotOccupied
            }
        }()
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }

    private func gridRoleBadge(_ role: UserRole) -> some View {
        Text(role.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    private var usersSkeletonList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { _ in
                    skeletonUserCard
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100)
            .padding(.top, 6)
        }
    }

    private var skeletonUserCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppConfig.tertiaryFillBg)
                    .frame(width: 64, height: 64)
                    .shimmering(active: true)

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(height: 14, cornerRadius: 7)
                        .frame(maxWidth: 130, alignment: .leading)
                    SkeletonBlock(height: 12, cornerRadius: 6)
                        .frame(maxWidth: 190, alignment: .leading)
                    HStack(spacing: 8) {
                        SkeletonBlock(height: 22, cornerRadius: 11)
                            .frame(width: 78)
                        SkeletonBlock(height: 22, cornerRadius: 11)
                            .frame(width: 78)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            HStack(spacing: 10) {
                SkeletonBlock(height: 12, cornerRadius: 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Divider()
                .overlay(AppConfig.outlineVariant.opacity(0.4))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            HStack {
                SkeletonBlock(height: 12, cornerRadius: 6)
                    .frame(width: 90, alignment: .leading)
                Spacer()
                SkeletonBlock(height: 32, cornerRadius: 16)
                    .frame(width: 110)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
    }

    // MARK: - Select All Row

    private var selectAllRow: some View {
        let allSelected = pendingUsers.allSatisfy { selectedUIDs.contains($0.uid) }
        return Button {
            withAnimation(.standard) {
                if allSelected {
                    pendingUsers.forEach { selectedUIDs.remove($0.uid) }
                } else {
                    pendingUsers.forEach { selectedUIDs.insert($0.uid) }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(allSelected ? AppConfig.darkText : AppConfig.subtleGray)
                    .font(.title3)
                Text(allSelected ? L10n.deselectAll : L10n.selectAllCount(pendingUsers.count))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppConfig.darkText)
                Spacer()
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .background(AppConfig.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
            .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Bulk Action Bar

    private var bulkActionBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(AppConfig.outlineVariant.opacity(0.5))
            VStack(spacing: 12) {
                // Role picker for bulk
                Menu {
                    ForEach(UserRole.allCases, id: \.rawValue) { role in
                        Button {
                            Haptics.selection()
                            bulkRole = role
                        } label: {
                            HStack {
                                Text(role.displayName)
                                if bulkRole == role {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray)
                            .frame(width: 20)
                        Text(L10n.activateAs)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppConfig.darkText)
                        Spacer()
                        Text(bulkRole.displayName)
                            .font(.subheadline)
                            .foregroundStyle(AppConfig.subtleGray)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppConfig.subtleGray.opacity(0.65))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppConfig.separatorSoft, lineWidth: 1)
                    )
                }
                .buttonStyle(ScaleButtonStyle())

                // Activate button
                Button {
                    Task { await bulkActivate() }
                } label: {
                    HStack(spacing: 8) {
                        if isBulkActivating {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(L10n.activateNUsers(selectedUIDs.count))
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isBulkActivating ? AppConfig.darkText.opacity(0.6) : AppConfig.darkText)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isBulkActivating || isBulkDeleting)

                // Delete button
                Button {
                    Haptics.destructive()
                    Task { await bulkDelete() }
                } label: {
                    HStack(spacing: 8) {
                        if isBulkDeleting {
                            ProgressView().tint(AppConfig.spotOccupied).scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(L10n.deleteNUsers(selectedUIDs.count))
                            .fontWeight(.bold)
                    }
                    .foregroundStyle(AppConfig.spotOccupied)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppConfig.spotOccupied.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(AppConfig.spotOccupied.opacity(0.3), lineWidth: 1.5))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isBulkActivating || isBulkDeleting)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 34)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - User Row

    private func userRow(_ user: AppUser) -> some View {
        let isMe       = user.uid == authManager.currentUser?.uid
        let isSelected = selectedUIDs.contains(user.uid)

        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                // Selection checkbox (only in select mode for pending users)
                if isSelecting && user.isPending {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? AppConfig.darkText : AppConfig.subtleGray)
                        .font(.system(size: 22))
                        .padding(.top, 4)
                        .transition(.scale.combined(with: .opacity))
                }

                // Avatar
                UserAvatarView(user: user, size: 64, showStroke: true)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(user.displayName)
                            .font(.headline)
                            .foregroundStyle(AppConfig.darkText)
                            .lineLimit(1)
                        if isMe {
                            Text(L10n.you)
                                .font(.caption2.weight(.semibold)).tracking(1)
                                .foregroundStyle(AppConfig.darkText)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(AppConfig.surfaceHigh)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1)
                                )
                        }
                    }
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                    CompanyBadgeView(badge: user.companyBadge, compact: false)
                    HStack(spacing: 8) {
                        statusBadge(user.status)
                        roleBadge(user.role)
                        if user.strikes > 0 || user.suspensionCount > 0 {
                            strikeBadge(user)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20).padding(.top, 20)

            if !user.registrationPlate.isEmpty || !user.carDescription.isEmpty || !user.carColor.isEmpty || !user.carType.isEmpty {
                HStack(spacing: 10) {
                    VehicleMiniatureView(
                        carType: user.carType,
                        colorHex: user.carColor,
                        description: user.carDescription,
                        presetID: user.vehicleMiniaturePresetID.isEmpty ? nil : user.vehicleMiniaturePresetID
                    )
                    .frame(width: 42, height: 24)
                    Text(vehicleSummary(for: user))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppConfig.subtleGray)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.top, 10)
            }

            Divider()
                .overlay(AppConfig.separatorStrong)
                .padding(.horizontal, 20).padding(.top, 16)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text(user.createdAt, style: .date)
                        .font(.caption)
                }
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
                Spacer()
                if !isSelecting { detailButton(for: user) }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .background(isSelected ? AppConfig.accent.opacity(0.07) : AppConfig.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
        .overlay(
            RoundedRectangle(cornerRadius: AppConfig.radius16)
                .stroke(isSelected ? AppConfig.accent.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .cardShadow()
    }

    private func detailButton(for user: AppUser) -> some View {
        Button {
            userDetailSheetUser = user
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.subheadline.weight(.semibold))
                Text("Detail")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(AppConfig.darkText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .background(AppConfig.surfaceHigh)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(for user: AppUser) -> some View {
        switch user.status {
        case .pending:
            HStack(spacing: 8) {
                // Quick approve
                Button {
                    selectedRole = .user
                    let uid = user.uid
                    Task {
                        await authManager.activateUser(user, role: .user)
                        Haptics.notify(.success)
                        withAnimation { recentlyActivatedUID = uid }
                        try? await Task.sleep(nanoseconds: 900_000_000)
                        withAnimation { recentlyActivatedUID = nil }
                    }
                } label: {
                    ZStack {
                        if recentlyActivatedUID == user.uid {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppConfig.darkText)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppConfig.darkText)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(AppConfig.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppConfig.separatorSoft, lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())

                // Quick reject
                Button {
                    userToQuickReject = user
                    showQuickRejectAlert = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppConfig.spotOccupied)
                        .frame(width: 44, height: 44)
                        .background(AppConfig.spotOccupied.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppConfig.spotOccupied.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())

                // Review detail OR delete outright
                Menu {
                    Button {
                        selectedRole = .user
                        rejectionReasonText = ""
                        userToActivate = user
                    } label: {
                        Label(L10n.reviewRequest, systemImage: "person.badge.checkmark")
                    }
                    Button(role: .destructive) {
                        userToDelete = user
                        showDeleteAlert = true
                    } label: {
                        Label(L10n.deleteUser, systemImage: "trash")
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(L10n.reviewRequest).font(.subheadline).fontWeight(.semibold)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(AppConfig.darkText)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                    .background(AppConfig.surfaceHigh)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
                }
                .buttonStyle(ScaleButtonStyle())
            }

        case .active:
            Menu {
                Section(L10n.changeRole) {
                    ForEach(UserRole.allCases, id: \.rawValue) { role in
                        Button { applyRoleChange(for: user, to: role) } label: {
                            HStack {
                                neutralMenuLabel(role.displayName, systemImage: roleIcon(role))
                                Spacer()
                                if user.role == role {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        .disabled(user.role == role)
                    }
                }
                Section {
                    Button {
                        editPlate       = user.registrationPlate
                        editCar         = user.carDescription
                        editCarType     = user.carType
                        editColor       = normalizedCarColor(for: user)
                        userToEditVehicle = user
                    } label: { neutralMenuLabel(L10n.editVehicle, systemImage: "car.side.fill") }
                }
                Section {
                    Button {
                        strikeReason = ""
                        userToStrike = user
                    } label: { neutralMenuLabel("Warnings", systemImage: "exclamationmark.triangle.fill") }

                    if user.strikes > 0 {
                        Button(role: .destructive) {
                            Task { await authManager.adminRemoveStrike(from: user) }
                        } label: {
                            Label("Remove Latest Warning", systemImage: "minus.circle.fill")
                        }
                    }
                }
                Section {
                    Button(role: .destructive) {
                        userToSuspend = user; showSuspendAlert = true
                    } label: { Label(L10n.suspend, systemImage: "person.badge.minus") }

                    if user.uid != authManager.currentUser?.uid {
                        Button(role: .destructive) {
                            userToDelete = user; showDeleteAlert = true
                        } label: { Label(L10n.deleteUser, systemImage: "trash.fill") }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle").font(.subheadline.weight(.semibold))
                    Text(L10n.manage).font(.subheadline).fontWeight(.medium)
                }
                .foregroundStyle(AppConfig.darkText)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .background(AppConfig.surfaceHigh)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            .tint(AppConfig.darkText)

        case .suspended:
            Menu {
                Button { Task { await authManager.adminRestoreUser(user) } } label: {
                    neutralMenuLabel("Clear Suspension", systemImage: "arrow.uturn.up.circle.fill")
                }
                Button {
                    strikeReason = ""
                    userToStrike = user
                } label: {
                    neutralMenuLabel("View Warnings", systemImage: "exclamationmark.triangle.fill")
                }
                Button {
                    editPlate       = user.registrationPlate
                    editCar         = user.carDescription
                    editCarType     = user.carType
                    editColor       = normalizedCarColor(for: user)
                    userToEditVehicle = user
                } label: { neutralMenuLabel(L10n.editVehicle, systemImage: "car.side.fill") }
                Button(role: .destructive) {
                    userToDelete = user; showDeleteAlert = true
                } label: { Label(L10n.deleteUser, systemImage: "trash.fill") }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle").font(.subheadline.weight(.semibold))
                    Text(L10n.restore).font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(AppConfig.darkText)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .background(AppConfig.surfaceHigh)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
            }
            .buttonStyle(ScaleButtonStyle())
            .tint(AppConfig.darkText)
        }
    }

    private func neutralMenuLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private func warningSectionHeader(_ text: String) -> some View {
        Text(text)
            .textCase(nil)
            .font(.body.weight(.semibold))
            .foregroundStyle(AppConfig.subtleGray)
    }

    private func applyRoleChange(for user: AppUser, to role: UserRole) {
        guard user.role != role else {
            Haptics.selection()
            return
        }

        if var openUser = userDetailSheetUser, openUser.uid == user.uid {
            openUser.role = role
            userDetailSheetUser = openUser
        }

        Task {
            await authManager.updateUserRole(user, role: role)
            Haptics.notify(.success)
            ToastManager.shared.show("Role updated to \(role.displayName)", style: .success)

            if let refreshed = authManager.allUsers.first(where: { $0.uid == user.uid }) {
                userDetailSheetUser = refreshed
            }
        }
    }

    // MARK: - User Detail Sheet

    private func userDetailSheet(user: AppUser) -> some View {
        let liveUser = authManager.allUsers.first(where: { $0.uid == user.uid }) ?? user
        let parsedVehicle = CarData.splitMakeModel(liveUser.carDescription)
        let hasVehicle = !liveUser.registrationPlate.isEmpty || !liveUser.carDescription.isEmpty || !liveUser.carColor.isEmpty || !liveUser.carType.isEmpty
        let hasSpecificMiniature = VehicleMiniatureView.hasSpecificMiniature(
            carType: liveUser.carType,
            description: liveUser.carDescription,
            presetID: liveUser.vehicleMiniaturePresetID.isEmpty ? nil : liveUser.vehicleMiniaturePresetID
        )
        let vehiclePrimary = {
            let composed = [parsedVehicle.make, parsedVehicle.model]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !composed.isEmpty { return composed }
            return liveUser.carDescription
        }()
        return NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(spacing: 16) {
                            if hasSpecificMiniature {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppConfig.surfaceLow)
                                    VehicleMiniatureView(
                                        carType: liveUser.carType,
                                        colorHex: liveUser.carColor,
                                        description: liveUser.carDescription,
                                        presetID: liveUser.vehicleMiniaturePresetID.isEmpty ? nil : liveUser.vehicleMiniaturePresetID
                                    )
                                    .frame(width: 252, height: 140)
                                }
                                .frame(height: 160)
                            } else {
                                UserAvatarView(user: liveUser, size: 88, showStroke: true)
                            }

                            VStack(spacing: 4) {
                                Text(liveUser.displayName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppConfig.darkText)
                                Text(liveUser.email)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConfig.subtleGray)
                            }

                            HStack(spacing: 8) {
                                statusBadge(liveUser.status)
                                roleBadge(liveUser.role)
                                if liveUser.strikes > 0 || liveUser.suspensionCount > 0 {
                                    strikeBadge(liveUser)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Vehicle")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)

                            if hasVehicle {
                                keyValueRow(label: "Model", value: vehiclePrimary)
                                Divider().overlay(AppConfig.separatorSoft)
                                keyValueRow(label: "Plate", value: liveUser.registrationPlate)
                                Divider().overlay(AppConfig.separatorSoft)
                                keyValueRow(label: "Color", value: vehicleColorName(for: liveUser))
                            } else {
                                Text("No vehicle details")
                                    .font(.subheadline)
                                    .foregroundStyle(AppConfig.subtleGray)
                            }
                        }
                        .padding(16)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Account")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                            keyValueRow(label: "Created", value: liveUser.createdAt.formatted(date: .abbreviated, time: .omitted))
                            Divider().overlay(AppConfig.separatorSoft)
                            keyValueRow(label: "Email", value: liveUser.email, allowMultilineValue: true)
                            Divider().overlay(AppConfig.separatorSoft)
                            keyValueRow(label: L10n.companyBadge, value: companyBadgeLabel(liveUser.companyBadge))
                        }
                        .padding(16)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actions")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)

                            if liveUser.status == .pending {
                                detailActionButton(title: L10n.reviewRequest, icon: "person.badge.checkmark") {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        selectedRole = .user
                                        rejectionReasonText = ""
                                        userToActivate = liveUser
                                    }
                                }
                            }

                            detailActionButton(title: L10n.editVehicle, icon: "car.side.fill", showsChevron: true) {
                                userDetailSheetUser = nil
                                DispatchQueue.main.async {
                                    editPlate = liveUser.registrationPlate
                                    editCar = liveUser.carDescription
                                    editCarType = liveUser.carType
                                    editColor = normalizedCarColor(for: liveUser)
                                    userToEditVehicle = liveUser
                                }
                            }

                            detailActionButton(title: "Warnings", icon: "exclamationmark.triangle.fill", showsChevron: true) {
                                userDetailSheetUser = nil
                                DispatchQueue.main.async {
                                    strikeReason = ""
                                    userToStrike = liveUser
                                }
                            }

                            detailActionButton(title: L10n.adminResetPassword, icon: "key.fill") {
                                userDetailSheetUser = nil
                                DispatchQueue.main.async {
                                    userToResetPassword = liveUser
                                    showResetPasswordAlert = true
                                }
                            }

                            Menu {
                                ForEach(UserRole.allCases, id: \.rawValue) { role in
                                    Button {
                                        applyRoleChange(for: liveUser, to: role)
                                    } label: {
                                        HStack {
                                            Label(role.displayName, systemImage: roleIcon(role))
                                            Spacer()
                                            if liveUser.role == role {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .disabled(liveUser.role == role)
                                }
                            } label: {
                                detailMenuRow(
                                    title: L10n.changeRole,
                                    icon: "person.crop.circle.badge.checkmark",
                                    value: liveUser.role.displayName
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Menu {
                                ForEach(CompanyBadge.sortedCases, id: \.rawValue) { badge in
                                    Button {
                                        Task { await authManager.adminUpdateUserCompanyBadge(liveUser, companyBadge: badge) }
                                    } label: {
                                        HStack {
                                            Text(companyBadgeLabel(badge))
                                            Spacer()
                                            if liveUser.companyBadge == badge {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .disabled(liveUser.companyBadge == badge)
                                }
                            } label: {
                                detailMenuRow(
                                    title: L10n.companyBadge,
                                    icon: "checkmark.seal.fill",
                                    value: companyBadgeLabel(liveUser.companyBadge)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            if liveUser.status == .suspended {
                                detailActionButton(title: "Clear Suspension", icon: "arrow.uturn.up.circle.fill") {
                                    Task { await authManager.adminRestoreUser(liveUser) }
                                }
                            } else {
                                detailActionButton(title: L10n.suspend, icon: "person.badge.minus", isDestructive: true) {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        userToSuspend = liveUser
                                        showSuspendAlert = true
                                    }
                                }
                            }

                            if liveUser.uid != authManager.currentUser?.uid {
                                detailActionButton(title: L10n.deleteUser, icon: "trash.fill", isDestructive: true) {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        userToDelete = liveUser
                                        showDeleteAlert = true
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(liveUser.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done) { userDetailSheetUser = nil }
                        .foregroundStyle(AppConfig.darkText)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func keyValueRow(label: String, value: String, allowMultilineValue: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
            Spacer(minLength: 8)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
                .multilineTextAlignment(.trailing)
                .lineLimit(allowMultilineValue ? 2 : 1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }

    private func vehicleColorName(for user: AppUser) -> String {
        if let named = AppConfig.carColors.first(where: { $0.hex == user.carColor })?.name {
            return named
        }
        return user.carColor
    }

    private func detailActionButton(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        showsChevron: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .frame(width: 28, height: 28)
                    .background(isDestructive ? AppConfig.spotOccupied.opacity(0.1) : AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDestructive ? AppConfig.spotOccupied.opacity(0.25) : AppConfig.separatorSoft, lineWidth: 1)
                    )
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppConfig.subtleGray)
                }
            }
            .foregroundStyle(isDestructive ? AppConfig.spotOccupied : AppConfig.darkText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isDestructive ? AppConfig.spotOccupied.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDestructive ? AppConfig.spotOccupied.opacity(0.22) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func detailMenuRow(title: String, icon: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppConfig.separatorSoft, lineWidth: 1)
                )
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.darkText)
            Spacer(minLength: 0)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Activate Sheet

    private func activateSheet(user: AppUser) -> some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        UserAvatarView(user: user, size: 72)
                        Text(user.displayName).font(.title3).fontWeight(.semibold).foregroundStyle(AppConfig.darkText)
                        Text(user.email).font(.subheadline).foregroundStyle(AppConfig.subtleGray)
                    }
                    .frame(maxWidth: .infinity).padding(20)
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.assignRole)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                        VStack(spacing: 8) {
                            ForEach(UserRole.allCases, id: \.rawValue) { role in
                                Button {
                                    withAnimation(.quick) { selectedRole = role }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: roleIcon(role)).font(.body)
                                            .foregroundStyle(selectedRole == role ? AppConfig.darkText : AppConfig.subtleGray)
                                            .frame(width: 32, height: 32)
                                            .background(selectedRole == role ? AppConfig.surfaceHigh : AppConfig.surfaceLow)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(role.displayName).fontWeight(.semibold).foregroundStyle(AppConfig.darkText)
                                            Text(roleDescription(role)).font(.caption).foregroundStyle(AppConfig.subtleGray)
                                        }
                                        Spacer()
                                        if selectedRole == role {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppConfig.darkText.opacity(0.85))
                                        }
                                    }
                                    .padding(14)
                                    .background(selectedRole == role ? AppConfig.groupedCardBg : AppConfig.cardBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedRole == role ? Color(uiColor: .separator) : AppConfig.separatorSoft, lineWidth: 1))
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                        }
                    }
                    Spacer()

                    // Activate button
                    Button {
                        userToActivate = nil
                        rejectionReasonText = ""
                        Task { await authManager.activateUser(user, role: selectedRole) }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(L10n.activateAsRole(selectedRole.displayName)).fontWeight(.semibold)
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppConfig.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Reject section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.rejectionReason)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)

                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppConfig.surfaceLow)
                            if rejectionReasonText.isEmpty {
                                Text(L10n.rejectionReasonHint)
                                    .font(.subheadline)
                                    .foregroundStyle(AppConfig.subtleGray.opacity(0.5))
                                    .padding(14)
                            }
                            TextEditor(text: $rejectionReasonText)
                                .font(.subheadline)
                                .foregroundStyle(AppConfig.darkText)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 80)
                        }
                        .frame(minHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {
                            let trimmed = rejectionReasonText.trimmingCharacters(in: .whitespacesAndNewlines)
                            let reason = trimmed.isEmpty
                                ? (L10n.lang == .czech ? "Žádost zamítnuta administrátorem." : "Registration rejected by administrator.")
                                : trimmed
                            userToActivate = nil
                            rejectionReasonText = ""
                            Task { await authManager.rejectUser(user, reason: reason) }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                Text(L10n.rejectAccount).fontWeight(.semibold)
                            }
                            .foregroundStyle(AppConfig.spotOccupied)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(AppConfig.spotOccupied.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(AppConfig.spotOccupied.opacity(0.3), lineWidth: 1.5))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle(L10n.reviewRequest).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        userToActivate = nil
                        rejectionReasonText = ""
                    }.foregroundStyle(AppConfig.subtleGray)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            AppEmptyStateCard(
                icon: selectedFilter == .pending ? "person.badge.clock" : "person.2.slash",
                title: emptyTitle,
                subtitle: emptyMessage
            )
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return L10n.lang == .czech ? "Žádné výsledky" : "No Results" }
        switch selectedFilter {
        case .pending:   return L10n.lang == .czech ? "Žádné čekající žádosti" : "No Pending Requests"
        case .active:    return L10n.lang == .czech ? "Žádní aktivní uživatelé" : "No Active Users"
        case .suspended: return L10n.lang == .czech ? "Žádní pozastavení uživatelé" : "No Suspended Users"
        case nil:        return L10n.lang == .czech ? "Žádní uživatelé" : "No Users"
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return L10n.noUsersMatchSearch }
        switch selectedFilter {
        case .pending:   return L10n.noPendingUsers
        case .active:    return L10n.noActiveUsers
        case .suspended: return L10n.noSuspendedUsers
        case nil:        return L10n.noUsersFound
        }
    }

    // MARK: - Bulk Activate

    private func bulkActivate() async {
        guard !selectedUIDs.isEmpty else { return }
        isBulkActivating = true
        let usersToActivate = authManager.allUsers.filter { selectedUIDs.contains($0.uid) }
        for user in usersToActivate {
            await authManager.activateUser(user, role: bulkRole)
        }
        Haptics.notify(.success)
        withAnimation(.standard) {
            selectedUIDs.removeAll()
            isSelecting      = false
            isBulkActivating = false
        }
    }

    // MARK: - Bulk Delete

    private func bulkDelete() async {
        guard !selectedUIDs.isEmpty else { return }
        isBulkDeleting = true
        let usersToDelete = authManager.allUsers.filter { selectedUIDs.contains($0.uid) }
        for user in usersToDelete {
            _ = await authManager.adminDeleteUser(user)
        }
        Haptics.notify(.warning)
        withAnimation(.standard) {
            selectedUIDs.removeAll()
            isSelecting    = false
            isBulkDeleting = false
        }
    }

    // MARK: - Helpers

    private func refresh() async {
        isLoading = true
        await authManager.fetchAllUsers()
        isLoading = false
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(name.prefix(2)).uppercased()
    }

    private func avatarColor(for user: AppUser) -> Color {
        switch user.role {
        case .admin:      return AppConfig.accent
        case .privileged: return AppConfig.infoTint
        case .user:       return AppConfig.subtleGray
        }
    }

    private func roleIcon(_ role: UserRole) -> String {
        switch role {
        case .admin:      return "checkmark.shield.fill"
        case .privileged: return "star.fill"
        case .user:       return "person.fill"
        }
    }

    private func roleDescription(_ role: UserRole) -> String {
        if L10n.lang == .czech {
            switch role {
            case .admin:      return "Plný přístup, správa uživatelů a rezervací"
            case .privileged: return "Rezervace až 7 dní dopředu a pro ostatní"
            case .user:       return "Standardní přístup, rezervace až 3 dny dopředu"
            }
        }
        switch role {
        case .admin:      return "Full access, can manage users & bookings"
        case .privileged: return "Can book up to 7 days ahead & book for others"
        case .user:       return "Standard access, book up to 3 days ahead"
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: UserStatus) -> some View {
        let (color, icon): (Color, String) = {
            switch status {
            case .pending:   return (AppConfig.warning, "clock.fill")
            case .active:    return (AppConfig.activeGreen, "checkmark.circle.fill")
            case .suspended: return (AppConfig.spotOccupied, "minus.circle.fill")
            }
        }()
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
            Text(status.displayName)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.1)).clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 1))
    }

    @ViewBuilder
    private func roleBadge(_ role: UserRole) -> some View {
        HStack(spacing: 4) {
            Image(systemName: roleIcon(role))
                .font(.caption2.weight(.semibold))
            Text(role.displayName)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(AppConfig.darkText)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(AppConfig.surfaceLow)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppConfig.separatorSoft, lineWidth: 1))
    }

    private func companyBadgeLabel(_ badge: CompanyBadge) -> String {
        switch badge {
        case .omega: return L10n.omegaLabel
        case .essilorLuxottica: return L10n.essilorLuxotticaLabel
        case .grandVision: return L10n.grandVisionLabel
        case .none: return L10n.noneLabel
        }
    }

    // MARK: - Strike Badge

    @ViewBuilder
    private func strikeBadge(_ user: AppUser) -> some View {
        let color: Color = user.isSuspended ? AppConfig.spotOccupied : (user.strikes >= 2 ? AppConfig.warning : .yellow)
        Button {
            strikeReason = ""
            userToStrike = user
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                Text(user.isSuspended ? "Suspended" : "\(user.strikes)/3")
                    .font(.caption.weight(.semibold))
                if user.suspensionCount > 0 {
                    Text("(\(user.suspensionCount)×)")
                        .font(.caption2.weight(.medium))
                }
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.1)).clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Strike Sheet

    private func strikeSheet(user: AppUser) -> some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        UserAvatarView(user: user, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        warningSummaryPill(for: user)
                    }
                    .padding(.vertical, 4)
                }.listRowBackground(AppConfig.groupedCardBg)

                if user.isSuspended, let liftDate = user.suspensionLiftDate {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(AppConfig.spotOccupied)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Suspended until")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppConfig.spotOccupied)
                                Text(liftDate, style: .date)
                                    .font(.subheadline.weight(.bold))
                            }
                            Spacer()
                            Button("Lift Now") {
                                userToStrike = nil
                                Task { await authManager.adminRestoreUser(user) }
                            }
                            .font(.caption.weight(.bold))
                            .buttonStyle(.borderedProminent)
                            .tint(AppConfig.darkText)
                        }
                    }
                } else if user.suspensionCount > 0 {
                    Section {
                        Label("Suspended \(user.suspensionCount)× in total", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !user.strikeHistory.isEmpty {
                    Section {
                        ForEach(Array(user.strikeHistory.reversed())) { entry in
                            warningHistoryRow(entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        userToStrike = nil
                                        Haptics.destructive()
                                        Task { await authManager.adminDeleteStrikeEntry(entry, from: user) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(AppConfig.danger)
                                }
                        }
                    } header: {
                        warningSectionHeader("Warning history")
                    } footer: {
                        Text("Swipe left on any warning to delete it.")
                    }
                }

                if user.strikes > 0 && !user.isSuspended {
                    Section {
                        Button {
                            userToStrike = nil
                            Task { await authManager.adminRemoveStrike(from: user) }
                        } label: {
                            Label("Remove Latest Warning (\(user.strikes) → \(user.strikes - 1))", systemImage: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        warningSectionHeader("Manage warnings")
                    }
                }

                if !user.isSuspended {
                    Section {
                        TextEditor(text: $strikeReason)
                            .frame(minHeight: 84)

                        let nextStrike = user.strikes + 1
                        let willSuspend = nextStrike >= 3
                        Button {
                            let reason = strikeReason
                            userToStrike = nil
                            Task { await authManager.assignStrike(to: user, reason: reason) }
                        } label: {
                            HStack(spacing: 8) {
                                if isAssigningStrike {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                } else {
                                    Image(systemName: willSuspend ? "lock.fill" : "exclamationmark.triangle.fill")
                                }
                                Text(willSuspend ? "Assign Warning & Suspend" : "Assign Warning (\(nextStrike)/3)")
                                    .fontWeight(.bold)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(willSuspend ? AppConfig.spotOccupied : AppConfig.warning)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(isAssigningStrike)
                    } header: {
                        warningSectionHeader("Manage warnings")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppConfig.pageBg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Warnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) { userToStrike = nil }
                        .foregroundStyle(AppConfig.darkText)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func warningHistoryRow(_ entry: StrikeEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(entry.strikeNumber)")
                .font(.system(.footnote, design: .rounded, weight: .black))
                .foregroundStyle(entry.suspensionTriggered ? AppConfig.spotOccupied : AppConfig.warning)
                .frame(width: 28, height: 28)
                .background(entry.suspensionTriggered
                    ? AppConfig.spotOccupied.opacity(0.15)
                    : AppConfig.warning.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.reason)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(entry.assignedAt, style: .date)
                    Text("·")
                    Text("by \(entry.assignedBy)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if entry.suspensionTriggered {
                    Label("Triggered suspension", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppConfig.spotOccupied)
                }
            }
            Spacer()
            Image(systemName: "trash")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.danger.opacity(0.85))
        }
        .padding(.vertical, 4)
    }

    private func warningSummaryPill(for user: AppUser) -> some View {
        let color: Color = user.isSuspended ? AppConfig.danger : (user.strikes >= 2 ? AppConfig.warning : .secondary)
        return HStack(spacing: 6) {
            Image(systemName: user.isSuspended ? "lock.fill" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
            Text(user.isSuspended ? "Suspended" : "\(user.strikes) of 3")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(AppConfig.groupedCardBg)
        .clipShape(Capsule())
    }

    // MARK: - Edit Vehicle Sheet

    private func editVehicleSheet(user: AppUser) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // User header
                    HStack(spacing: 14) {
                        if VehicleMiniatureView.hasSpecificMiniature(carType: editCarType, description: editCar, presetID: editPresetID.isEmpty ? nil : editPresetID) {
                            VehicleMiniatureView(
                                carType: editCarType,
                                colorHex: editColor,
                                description: editCar,
                                presetID: editPresetID.isEmpty ? nil : editPresetID
                            )
                            .frame(width: 90, height: 54)
                        } else {
                            UserAvatarView(user: user, size: 52)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName).font(.headline).foregroundStyle(AppConfig.darkText)
                            Text(user.email).font(.caption).foregroundStyle(AppConfig.subtleGray)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Car make + model
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.carModel)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                        VStack(spacing: 8) {
                            Menu {
                                ForEach(vehicleCatalog.makes(merging: CarData.makes), id: \.self) { make in
                                    Button {
                                        editSelectedMake = make
                                        editSelectedModel = ""
                                        editCar = make
                                    } label: {
                                        HStack(spacing: 8) {
                                            CarMakerLogoBadge(make: make, size: 18)
                                            Text(make)
                                        }
                                    }
                                }
                            } label: {
                                makeModelPickerRow(
                                    icon: "building.2.crop.circle",
                                    title: lang.language == .czech ? "Značka" : "Make",
                                    value: editSelectedMake.isEmpty ? (lang.language == .czech ? "Vyberte značku" : "Choose make") : editSelectedMake,
                                    isPlaceholder: editSelectedMake.isEmpty,
                                    makerLogo: editSelectedMake.isEmpty ? nil : editSelectedMake
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Menu {
                                if editSelectedMake.isEmpty {
                                    Button(lang.language == .czech ? "Nejprve vyberte značku" : "Select make first") {}
                                        .disabled(true)
                                } else {
                                    ForEach(vehicleCatalog.models(for: editSelectedMake, merging: CarData.models(for: editSelectedMake)), id: \.self) { model in
                                        Button(model) {
                                            editSelectedModel = model
                                            editCar = CarData.compose(make: editSelectedMake, model: model)
                                        }
                                    }
                                }
                            } label: {
                                makeModelPickerRow(
                                    icon: "car.side",
                                    title: lang.language == .czech ? "Model" : "Model",
                                    value: editSelectedModel.isEmpty ? (lang.language == .czech ? "Vyberte model" : "Choose model") : editSelectedModel,
                                    isPlaceholder: editSelectedModel.isEmpty
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }

                    // Registration plate
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.registrationPlate)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                        TextField("1A2 3456", text: $editPlate)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(14)
                            .background(AppConfig.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vehicle icon")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(AppConfig.subtleGray)
                        Button {
                            Haptics.selection()
                            showEditVehiclePresetSheet = true
                        } label: {
                            let editPreset: VehicleMiniaturePreset? = {
                                if !editPresetID.isEmpty { return VehicleMiniaturePreset.all.first { $0.id == editPresetID } }
                                return VehicleMiniaturePreset.matching(description: editCar, carType: editCarType)
                            }()
                            iconPickerRow(
                                title: lang.language == .czech ? "Ikona" : "Icon",
                                value: editPreset?.title ?? "Choose Icon",
                                isPlaceholder: editPreset == nil
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }

                    VehicleMiniatureView(
                        carType: editCarType,
                        colorHex: editColor,
                        description: editCar,
                        presetID: editPresetID.isEmpty ? nil : editPresetID
                    )
                    .frame(width: 148, height: 82)
                    .frame(maxWidth: .infinity, alignment: .center)

                    DisclosureGroup(isExpanded: $showEditVehicleColorPicker) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 10) {
                            ForEach(AppConfig.carColors, id: \.hex) { color in
                                let isSelected = editColor == color.hex
                                Button {
                                    withAnimation(.quick) { editColor = color.hex }
                                } label: {
                                    Circle().fill(Color(hex: color.hex)).frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(isSelected ? AppConfig.darkText : AppConfig.outlineVariant.opacity(0.5), lineWidth: isSelected ? 3 : 1))
                                        .overlay {
                                            if isSelected {
                                                Image(systemName: "checkmark").font(.caption2.weight(.semibold))
                                                    .foregroundStyle(color.hex == "#FFFFFF" || color.hex == "#C0C0C0" || color.hex == "#F9A825" ? Color.black : Color.white)
                                            }
                                        }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                        }
                        .padding(.top, 8)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "paintpalette")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                                .frame(width: 24)
                            Text(L10n.carColor)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppConfig.darkText)
                            Spacer()
                            if let color = AppConfig.carColors.first(where: { $0.hex == editColor }) {
                                Text(color.name).font(.caption).foregroundStyle(AppConfig.subtleGray)
                            }
                        }
                    }
                    .tint(AppConfig.darkText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1)
                    )

                }
                .padding(20)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppConfig.pageBg.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.editVehicle).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) { userToEditVehicle = nil }
                        .foregroundStyle(AppConfig.subtleGray)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.save) {
                        let plate    = editPlate
                        let car      = editCar
                        let color    = editColor
                        let carType  = editCarType
                        let presetID = editPresetID
                        userToEditVehicle = nil
                        Task { await authManager.adminUpdateUserVehicle(user, plate: plate, car: car, color: color, carType: carType, vehicleMiniaturePresetID: presetID) }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConfig.darkText)
                }
            }
            .onAppear {
                editPresetID = user.vehicleMiniaturePresetID
                editColor = normalizedCarColor(for: user)
                syncEditVehicleMakeModelFromDescription()
                showEditVehicleColorPicker = false
            }
            .sheet(isPresented: $showEditVehiclePresetSheet) {
                VehicleMiniaturePresetPickerSheet(
                    title: "Choose Vehicle Icon",
                    selectedColorHex: editColor,
                    selectedPresetID: editPresetID.isEmpty ? VehicleMiniaturePreset.matching(description: editCar, carType: editCarType)?.id : editPresetID,
                    selectedMake: editSelectedMake,
                    selectedModel: editSelectedModel
                ) { preset in
                    editPresetID = preset.id
                    editCar = preset.searchDescription
                    editCarType = ""
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func normalizedCarColor(for user: AppUser) -> String {
        if AppConfig.carColors.contains(where: { $0.hex == user.carColor }) {
            return user.carColor
        }
        return AppConfig.carColors.first?.hex ?? ""
    }

    private func makeModelPickerRow(
        icon: String,
        title: String,
        value: String,
        isPlaceholder: Bool,
        makerLogo: String? = nil
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            HStack(spacing: 8) {
                if let makerLogo, !isPlaceholder {
                    CarMakerLogoBadge(make: makerLogo, size: 19)
                }
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(isPlaceholder ? AppConfig.subtleGray : AppConfig.darkText)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1))
    }

    private func iconPickerRow(
        title: String,
        value: String,
        isPlaceholder: Bool
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppConfig.darkText)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(isPlaceholder ? AppConfig.subtleGray : AppConfig.darkText)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppConfig.subtleGray.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(AppConfig.surfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppConfig.outlineVariant.opacity(0.35), lineWidth: 1))
    }

    private func syncEditVehicleMakeModelFromDescription() {
        let localParsed = CarData.splitMakeModel(editCar)
        let parsed = localParsed.make.isEmpty ? vehicleCatalog.splitMakeModel(editCar) : localParsed
        editSelectedMake = parsed.make
        editSelectedModel = parsed.model
    }

    private func vehicleSummary(for user: AppUser) -> String {
        var details = [user.registrationPlate, user.carDescription].filter { !$0.isEmpty }
        let typeLabel = carTypeLabel(for: user)
        if !typeLabel.isEmpty {
            details.append(typeLabel)
        }
        if let colorName = AppConfig.carColors.first(where: { $0.hex == user.carColor })?.name {
            details.append(colorName)
        }
        return details.joined(separator: "  ·  ")
    }

    private func carTypeLabel(for user: AppUser) -> String {
        guard !user.carType.isEmpty else { return "" }
        if let type = CarBodyType(rawValue: user.carType) {
            return type.label
        }
        return user.carType
    }
}



#Preview {
    AdminUsersView()
        .environmentObject(AuthManager())
        .environmentObject(BookingManager())
}

// MARK: - Checkmark Draw-On Animation

private struct CheckmarkDrawView: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        CheckmarkShape()
            .trim(from: 0, to: progress)
            .stroke(
                AppConfig.activeGreen,
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.28)) { progress = 1.0 }
            }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to:    CGPoint(x: rect.width * 0.14, y: rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.78))
        path.addLine(to: CGPoint(x: rect.width * 0.86, y: rect.height * 0.22))
        return path
    }
}
