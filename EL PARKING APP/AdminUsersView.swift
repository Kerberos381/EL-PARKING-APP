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

    @State private var selectedFilter: UserStatus? = nil
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
    @State private var editPickerColor  = Color.red
    @State private var editCarSuggestions: [String] = []
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

    // MARK: - Filtered Users

    private var normalizedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredUsers: [AppUser] {
        var users = authManager.allUsers
        if let filter = selectedFilter { users = users.filter { $0.status == filter } }
        if !normalizedSearchQuery.isEmpty {
            users = users.filter {
                $0.displayName.lowercased().contains(normalizedSearchQuery) ||
                $0.email.lowercased().contains(normalizedSearchQuery) ||
                $0.registrationPlate.lowercased().contains(normalizedSearchQuery) ||
                $0.carDescription.lowercased().contains(normalizedSearchQuery) ||
                $0.carType.lowercased().contains(normalizedSearchQuery)
            }
        }
        return users.sorted { $0.displayName < $1.displayName }
    }

    private var userCounts: (pending: Int, active: Int, suspended: Int) {
        authManager.allUsers.reduce(into: (0, 0, 0)) { result, user in
            if user.isPending { result.pending += 1 }
            if user.isActive { result.active += 1 }
            if user.isSuspended { result.suspended += 1 }
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
                    userList
                }
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
                if selectedFilter == .pending && !pendingUsers.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
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
            .task { await refresh() }
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: L10n.all,       count: authManager.allUsers.count, filter: nil)
                filterPill(label: L10n.pending,   count: pendingCount,   filter: .pending)
                filterPill(label: L10n.activeFilter, count: activeCount, filter: .active)
                filterPill(label: L10n.suspended, count: suspendedCount, filter: .suspended)
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
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(isSelected ? .semibold : .medium)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(isSelected ? Color(uiColor: .tertiarySystemFill) : AppConfig.surfaceLow)
                        .clipShape(Capsule())
                }
            }
            .font(.subheadline)
            .foregroundStyle(isSelected ? Color.primary : Color.secondary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(isSelected ? Color(uiColor: .tertiarySystemGroupedBackground) : AppConfig.cardBg)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color(uiColor: .separator) : AppConfig.separatorSoft, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
        .refreshable {
            Haptics.selection()
            await refresh()
        }
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
                    .fill(Color(uiColor: .tertiarySystemFill))
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
                    .font(.system(size: 20))
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
                HStack(spacing: 10) {
                    Text(L10n.activateAs)
                        .font(.subheadline)
                        .foregroundStyle(AppConfig.subtleGray)
                    Picker(L10n.activateAs, selection: $bulkRole) {
                        ForEach(UserRole.allCases, id: \.rawValue) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }

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
                                .font(.system(size: 9, weight: .semibold)).tracking(1)
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
                        description: user.carDescription
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
        .shadow(color: .black.opacity(0.03), radius: 7, y: 2)
    }

    private func detailButton(for user: AppUser) -> some View {
        Button {
            userDetailSheetUser = user
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text("Detail")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(AppConfig.darkText)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
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
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AppConfig.darkText)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
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
                        .font(.system(size: 18, weight: .semibold))
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
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(AppConfig.darkText)
                    .padding(.horizontal, 14).padding(.vertical, 10)
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
                        Button { Task { await authManager.updateUserRole(user, role: role) } } label: {
                            neutralMenuLabel(role.displayName, systemImage: roleIcon(role))
                        }
                    }
                }
                Section {
                    Button {
                        editPlate       = user.registrationPlate
                        editCar         = user.carDescription
                        editCarType     = user.carType
                        editColor       = normalizedCarColor(for: user)
                        editPickerColor = AppConfig.carColors.map(\.hex).contains(user.carColor) ? .red : Color(hex: user.carColor)
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
                    Image(systemName: "ellipsis.circle").font(.system(size: 14, weight: .semibold))
                    Text(L10n.manage).font(.subheadline).fontWeight(.medium)
                }
                .foregroundStyle(AppConfig.darkText)
                .padding(.horizontal, 18).padding(.vertical, 10)
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
                    editPickerColor = AppConfig.carColors.map(\.hex).contains(user.carColor) ? .red : Color(hex: user.carColor)
                    userToEditVehicle = user
                } label: { neutralMenuLabel(L10n.editVehicle, systemImage: "car.side.fill") }
                Button(role: .destructive) {
                    userToDelete = user; showDeleteAlert = true
                } label: { Label(L10n.deleteUser, systemImage: "trash.fill") }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "ellipsis.circle").font(.system(size: 14, weight: .semibold))
                    Text(L10n.restore).font(.subheadline).fontWeight(.semibold)
                }
                .foregroundStyle(AppConfig.darkText)
                .padding(.horizontal, 18).padding(.vertical, 10)
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
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    // MARK: - User Detail Sheet

    private func userDetailSheet(user: AppUser) -> some View {
        NavigationStack {
            ZStack {
                AppConfig.pageBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        VStack(spacing: 12) {
                            UserAvatarView(user: user, size: 72, showStroke: true)
                            Text(user.displayName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppConfig.darkText)
                            Text(user.email)
                                .font(.subheadline)
                                .foregroundStyle(AppConfig.subtleGray)
                            HStack(spacing: 8) {
                                statusBadge(user.status)
                                roleBadge(user.role)
                                if user.strikes > 0 || user.suspensionCount > 0 {
                                    strikeBadge(user)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
                        .shadow(color: .black.opacity(0.03), radius: 7, y: 2)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("User Info")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)
                            if !user.registrationPlate.isEmpty || !user.carDescription.isEmpty || !user.carColor.isEmpty || !user.carType.isEmpty {
                                HStack(spacing: 10) {
                                    VehicleMiniatureView(
                                        carType: user.carType,
                                        colorHex: user.carColor,
                                        description: user.carDescription
                                    )
                                    .frame(width: 54, height: 30)
                                    Text(vehicleSummary(for: user))
                                        .font(.subheadline)
                                        .foregroundStyle(AppConfig.darkText)
                                        .lineLimit(2)
                                    Spacer()
                                }
                            }
                            detailInfoRow(icon: "calendar", title: "Created", value: user.createdAt.formatted(date: .abbreviated, time: .omitted))
                            detailInfoRow(icon: "envelope.fill", title: "Email", value: user.email)
                        }
                        .padding(16)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
                        .shadow(color: .black.opacity(0.03), radius: 7, y: 2)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Actions")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppConfig.subtleGray)

                            if user.status == .pending {
                                detailActionButton(title: L10n.reviewRequest, icon: "person.badge.checkmark") {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        selectedRole = .user
                                        rejectionReasonText = ""
                                        userToActivate = user
                                    }
                                }
                            }

                            detailActionButton(title: L10n.editVehicle, icon: "car.side.fill") {
                                userDetailSheetUser = nil
                                DispatchQueue.main.async {
                                    editPlate = user.registrationPlate
                                    editCar = user.carDescription
                                    editCarType = user.carType
                                    editColor = normalizedCarColor(for: user)
                                    editPickerColor = AppConfig.carColors.map(\.hex).contains(user.carColor) ? .red : Color(hex: user.carColor)
                                    userToEditVehicle = user
                                }
                            }

                            detailActionButton(title: "Warnings", icon: "exclamationmark.triangle.fill") {
                                userDetailSheetUser = nil
                                DispatchQueue.main.async {
                                    strikeReason = ""
                                    userToStrike = user
                                }
                            }

                            Menu {
                                ForEach(UserRole.allCases, id: \.rawValue) { role in
                                    Button {
                                        Task { await authManager.updateUserRole(user, role: role) }
                                    } label: {
                                        Label(role.displayName, systemImage: roleIcon(role))
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                    Text(L10n.changeRole)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(user.role.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppConfig.subtleGray)
                                }
                                .foregroundStyle(AppConfig.darkText)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(ScaleButtonStyle())

                            if user.status == .suspended {
                                detailActionButton(title: "Clear Suspension", icon: "arrow.uturn.up.circle.fill") {
                                    Task { await authManager.adminRestoreUser(user) }
                                }
                            } else {
                                detailActionButton(title: L10n.suspend, icon: "person.badge.minus", isDestructive: true) {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        userToSuspend = user
                                        showSuspendAlert = true
                                    }
                                }
                            }

                            if user.uid != authManager.currentUser?.uid {
                                detailActionButton(title: L10n.deleteUser, icon: "trash.fill", isDestructive: true) {
                                    userDetailSheetUser = nil
                                    DispatchQueue.main.async {
                                        userToDelete = user
                                        showDeleteAlert = true
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: AppConfig.radius16))
                        .shadow(color: .black.opacity(0.03), radius: 7, y: 2)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle(user.displayName)
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

    private func detailInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppConfig.subtleGray)
                .frame(width: 22, height: 22)
                .background(AppConfig.surfaceLow)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(AppConfig.separatorSoft, lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppConfig.subtleGray)
                Text(value.isEmpty ? "—" : value)
                    .font(.subheadline)
                    .foregroundStyle(AppConfig.darkText)
            }
            Spacer()
        }
    }

    private func detailActionButton(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(isDestructive ? AppConfig.spotOccupied.opacity(0.1) : AppConfig.surfaceLow)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isDestructive ? AppConfig.spotOccupied.opacity(0.25) : AppConfig.separatorSoft, lineWidth: 1)
                    )
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(isDestructive ? AppConfig.spotOccupied : AppConfig.darkText)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isDestructive ? AppConfig.spotOccupied.opacity(0.10) : AppConfig.surfaceLow)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isDestructive ? AppConfig.spotOccupied.opacity(0.25) : AppConfig.separatorSoft, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
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
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.assignRole)
                            .font(.caption).fontWeight(.semibold).tracking(1.0)
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
                                    .background(selectedRole == role ? Color(uiColor: .secondarySystemGroupedBackground) : AppConfig.cardBg)
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
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    // Reject section
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.rejectionReason)
                            .font(.caption).fontWeight(.semibold).tracking(1.2)
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
        case .privileged: return Color.blue
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
            case .pending:   return (.orange, "clock.fill")
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

    // MARK: - Strike Badge

    @ViewBuilder
    private func strikeBadge(_ user: AppUser) -> some View {
        let color: Color = user.isSuspended ? AppConfig.spotOccupied : (user.strikes >= 2 ? .orange : .yellow)
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
                }

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
                                    .tint(.red)
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
                            .background(willSuspend ? AppConfig.spotOccupied : Color.orange)
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
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(entry.suspensionTriggered ? AppConfig.spotOccupied : .orange)
                .frame(width: 28, height: 28)
                .background(entry.suspensionTriggered
                    ? AppConfig.spotOccupied.opacity(0.15)
                    : Color.orange.opacity(0.12))
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
                .foregroundStyle(.red.opacity(0.85))
        }
        .padding(.vertical, 4)
    }

    private func warningSummaryPill(for user: AppUser) -> some View {
        let color: Color = user.isSuspended ? .red : (user.strikes >= 2 ? .orange : .secondary)
        return HStack(spacing: 6) {
            Image(systemName: user.isSuspended ? "lock.fill" : "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold))
            Text(user.isSuspended ? "Suspended" : "\(user.strikes) of 3")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(Capsule())
    }

    // MARK: - Edit Vehicle Sheet

    private func editVehicleSheet(user: AppUser) -> some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // User header
                    HStack(spacing: 14) {
                        UserAvatarView(user: user, size: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName).font(.headline).foregroundStyle(AppConfig.darkText)
                            Text(user.email).font(.caption).foregroundStyle(AppConfig.subtleGray)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppConfig.cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Car make + model with suggestions
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.carModel)
                            .font(.caption).fontWeight(.semibold).tracking(1.2)
                            .foregroundStyle(AppConfig.subtleGray)
                        VStack(alignment: .leading, spacing: 0) {
                            TextField("e.g. Škoda Octavia", text: $editCar)
                                .autocorrectionDisabled()
                                .padding(14)
                                .background(AppConfig.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .onChange(of: editCar) { _, val in
                                    withAnimation(.quick) {
                                        editCarSuggestions = CarData.filter(val)
                                    }
                                }
                            if !editCarSuggestions.isEmpty {
                                VStack(spacing: 0) {
                                    ForEach(Array(editCarSuggestions.enumerated()), id: \.offset) { idx, suggestion in
                                        Button {
                                            withAnimation(.quick) {
                                                editCar = suggestion
                                                editCarSuggestions = []
                                            }
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(AppConfig.subtleGray)
                                                Text(suggestion).font(.subheadline).foregroundStyle(AppConfig.darkText)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 14).padding(.vertical, 10)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        if idx < editCarSuggestions.count - 1 { Divider().padding(.horizontal, 14) }
                                    }
                                }
                                .background(AppConfig.surfaceLow)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                                .padding(.top, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.quick, value: editCarSuggestions.isEmpty)
                    }

                    // Registration plate
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.registrationPlate)
                            .font(.caption).fontWeight(.semibold).tracking(1.2)
                            .foregroundStyle(AppConfig.subtleGray)
                        TextField("1A2 3456", text: $editPlate)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced).weight(.semibold))
                            .padding(14)
                            .background(AppConfig.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Body type chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.carBodyType)
                            .font(.caption).fontWeight(.semibold).tracking(1.2)
                            .foregroundStyle(AppConfig.subtleGray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(CarBodyType.allCases) { bodyType in
                                    let isSelected = editCarType == bodyType.rawValue
                                    Button {
                                        withAnimation(.quick) {
                                            editCarType = isSelected ? "" : bodyType.rawValue
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: bodyType.icon).font(.system(size: 12, weight: .semibold))
                                            Text(bodyType.label).font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(isSelected ? AppConfig.onAccent : AppConfig.subtleGray)
                                        .padding(.horizontal, 13).padding(.vertical, 8)
                                        .background(isSelected ? AppConfig.accent : AppConfig.surfaceLow)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(
                                            isSelected ? AppConfig.accentFg.opacity(0.3) : AppConfig.outlineVariant.opacity(0.4),
                                            lineWidth: 1
                                        ))
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }

                    VehicleMiniatureView(
                        carType: editCarType,
                        colorHex: editColor,
                        description: editCar
                    )
                    .frame(width: 82, height: 46)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)

                    // Color picker
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(L10n.carColor)
                                .font(.caption).fontWeight(.semibold).tracking(1.2)
                                .foregroundStyle(AppConfig.subtleGray)
                            Spacer()
                            if let color = AppConfig.carColors.first(where: { $0.hex == editColor }) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(hex: color.hex)).frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(AppConfig.outlineVariant.opacity(0.5), lineWidth: 1))
                                    Text(color.name).font(.caption.weight(.semibold)).foregroundStyle(AppConfig.darkText)
                                }
                            } else if !editColor.isEmpty {
                                HStack(spacing: 6) {
                                    Circle().fill(Color(hex: editColor)).frame(width: 14, height: 14)
                                        .overlay(Circle().stroke(AppConfig.outlineVariant.opacity(0.5), lineWidth: 1))
                                    Text(L10n.carColorCustom).font(.caption.weight(.semibold)).foregroundStyle(AppConfig.darkText)
                                }
                            }
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 10) {
                            ForEach(AppConfig.carColors, id: \.hex) { color in
                                let isSelected = editColor == color.hex
                                Button {
                                    withAnimation(.quick) { editColor = color.hex }
                                } label: {
                                    Circle().fill(Color(hex: color.hex)).frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(isSelected ? AppConfig.accentFg : AppConfig.outlineVariant.opacity(0.5), lineWidth: isSelected ? 3 : 1))
                                        .overlay {
                                            if isSelected {
                                                Image(systemName: "checkmark").font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(color.hex == "#FFFFFF" || color.hex == "#C0C0C0" || color.hex == "#F9A825" ? Color.black : Color.white)
                                            }
                                        }
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }

                            VehicleCustomColorButton(
                                selectedHex: $editColor,
                                pickerColor: $editPickerColor,
                                size: 28,
                                selectedStrokeWidth: 3,
                                checkmarkSize: 10,
                                plusSize: 13,
                                unselectedStroke: AppConfig.outlineVariant.opacity(0.5)
                            )
                        }
                        .padding(14)
                        .background(AppConfig.cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

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
                        let plate   = editPlate
                        let car     = editCar
                        let color   = editColor
                        let carType = editCarType
                        userToEditVehicle = nil
                        editCarSuggestions = []
                        Task { await authManager.adminUpdateUserVehicle(user, plate: plate, car: car, color: color, carType: carType) }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(AppConfig.accentFg)
                }
            }
            .onAppear {
                editColor = normalizedCarColor(for: user)
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
