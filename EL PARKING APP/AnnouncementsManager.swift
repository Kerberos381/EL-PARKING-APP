//
//  AnnouncementsManager.swift
//  EL PARKING APP
//
//  Real-time Firestore listener for announcements.
//  Admins: full CRUD. All users: read active announcements.
//

import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseCore
#if canImport(UIKit)
import UIKit
#endif

@MainActor
class AnnouncementsManager: ObservableObject {

    @Published var announcements: [Announcement] = []
    @Published var lastImageStorageError: String?

    /// Active, non-expired items: pinned first, then newest-first
    var activeAnnouncements: [Announcement] {
        let now = Date()
        return announcements
            .filter { $0.isActive && ($0.expiresAt == nil || $0.expiresAt! > now) }
            .sorted { a, b in
                if a.isPinned != b.isPinned { return a.isPinned }
                return a.createdAt > b.createdAt
            }
    }

    private lazy var db = Firestore.firestore()
    private lazy var storage = Storage.storage()
    private var listener: ListenerRegistration?

    init() {
        startListener()
        Task { await cleanupExpired() }
    }

    deinit { listener?.remove() }

    // MARK: - Listener

    private func startListener() {
        listener?.remove()
        listener = db.collection("announcements")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                let items = snapshot.documents.compactMap {
                    Announcement.fromFirestore($0.data(), id: $0.documentID)
                }
                Task { @MainActor in
                    self.announcements = items
                }
            }
    }

    func refresh() async {
        do {
            let snapshot = try await db.collection("announcements")
                .order(by: "createdAt", descending: true)
                .getDocuments()

            announcements = snapshot.documents.compactMap {
                Announcement.fromFirestore($0.data(), id: $0.documentID)
            }
        } catch {
            print("AnnouncementsManager refresh error: \(error.localizedDescription)")
        }
    }

    // MARK: - CRUD

    func create(title: String, body: String, emoji: String, isPinned: Bool, createdBy: String, expiresAt: Date? = nil, fields: [ContactField] = [], backgroundColorHex: String? = nil, imageURL: String? = nil, imageBase64: String? = nil, textColorMode: String = AnnouncementTextColorMode.auto.rawValue) async {
        let id = UUID().uuidString
        let item = Announcement(
            id: id, title: title, body: body, emoji: emoji,
            createdBy: createdBy, createdAt: Date(),
            isActive: true, isPinned: isPinned,
            expiresAt: expiresAt, fields: fields,
            backgroundColorHex: backgroundColorHex,
            imageURL: imageURL,
            imageBase64: imageBase64,
            textColorMode: textColorMode
        )
        do {
            try await db.collection("announcements").document(id).setData(item.toFirestore())
            PushNotificationManager.broadcast(title: "\(emoji) \(title)", body: body)
        } catch {
            print("AnnouncementsManager create error: \(error.localizedDescription)")
        }
    }

    func save(_ item: Announcement) async {
        do {
            try await db.collection("announcements").document(item.id).setData(item.toFirestore())
        } catch {
            print("AnnouncementsManager save error: \(error.localizedDescription)")
        }
    }

    func delete(_ item: Announcement) async {
        do {
            if item.imageURL != nil {
                await deleteImage(for: item.id)
            }
            try await db.collection("announcements").document(item.id).delete()
        } catch {
            print("AnnouncementsManager delete error: \(error.localizedDescription)")
        }
    }

    func toggleActive(_ item: Announcement) async {
        var updated = item; updated.isActive = !item.isActive
        await save(updated)
    }

    func togglePinned(_ item: Announcement) async {
        var updated = item; updated.isPinned = !item.isPinned
        await save(updated)
    }

    func renewExpiry(_ item: Announcement, additionalDays: Int = 30) async {
        var updated = item
        let base = item.expiresAt ?? Date()
        let newExpiry = max(base, Date())
        updated.expiresAt = Calendar.current.date(byAdding: .day, value: additionalDays, to: newExpiry)
        await save(updated)
    }

    // MARK: - Image Upload / Delete

    func uploadImage(_ imageData: Data, for announcementID: String) async -> String? {
        let objectPath = "announcements/\(announcementID).jpg"
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        lastImageStorageError = nil
        let refs = storageReferences(for: objectPath)
        var attemptMessages: [String] = []

        for ref in refs {
            do {
                let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            } catch {
                let message = storageErrorMessage(for: error, phase: "upload", objectPath: objectPath)
                attemptMessages.append(message)
                print("AnnouncementsManager uploadImage upload failed: \(message)")
                continue
            }

            // Storage metadata can occasionally lag immediately after upload.
            for attempt in 1...3 {
                do {
                    let url = try await ref.downloadURL()
                    return url.absoluteString
                } catch {
                    let nsError = error as NSError
                    let code = StorageErrorCode(rawValue: nsError.code)
                    if code == .objectNotFound && attempt < 3 {
                        try? await Task.sleep(nanoseconds: UInt64(250_000_000 * attempt))
                        continue
                    }

                    let message = storageErrorMessage(for: error, phase: "downloadURL", objectPath: objectPath)
                    attemptMessages.append(message)
                    print("AnnouncementsManager uploadImage downloadURL failed: \(message)")
                    break
                }
            }
        }

        let message = attemptMessages.joined(separator: " || ")
        lastImageStorageError = message.isEmpty ? "Upload failed for unknown reason." : message
        print("AnnouncementsManager uploadImage failed all bucket attempts: \(lastImageStorageError ?? "unknown")")
        return nil
    }

    private func storageReferences(for objectPath: String) -> [StorageReference] {
        var refs: [StorageReference] = [storage.reference().child(objectPath)]
        for bucket in storageBucketCandidates() {
            let ref = Storage.storage(url: "gs://\(bucket)").reference().child(objectPath)
            if !refs.contains(where: { $0.bucket == ref.bucket && $0.fullPath == ref.fullPath }) {
                refs.append(ref)
            }
        }
        return refs
    }

    private func storageBucketCandidates() -> [String] {
        var buckets: [String] = []

        if let configured = FirebaseApp.app()?.options.storageBucket, !configured.isEmpty {
            buckets.append(configured)
        }

        let defaultBucket = storage.reference().bucket
        if !defaultBucket.isEmpty {
            buckets.append(defaultBucket)
        }

        var expanded: [String] = []
        for bucket in buckets {
            expanded.append(bucket)
            if bucket.hasSuffix(".firebasestorage.app") {
                expanded.append(bucket.replacingOccurrences(of: ".firebasestorage.app", with: ".appspot.com"))
            } else if bucket.hasSuffix(".appspot.com") {
                expanded.append(bucket.replacingOccurrences(of: ".appspot.com", with: ".firebasestorage.app"))
            }
        }

        return Array(NSOrderedSet(array: expanded)) as? [String] ?? expanded
    }

    func deleteImage(for announcementID: String) async {
        let objectPath = "announcements/\(announcementID).jpg"
        for ref in storageReferences(for: objectPath) {
            do {
                try await ref.delete()
                return
            } catch {
                let nsError = error as NSError
                let code = StorageErrorCode(rawValue: nsError.code)
                if code == .objectNotFound {
                    continue
                }
                let message = storageErrorMessage(for: error, phase: "delete", objectPath: objectPath)
                print("AnnouncementsManager deleteImage error: \(message)")
                return
            }
        }
        print("AnnouncementsManager deleteImage skipped (already missing): \(objectPath)")
    }

    private func storageErrorMessage(for error: Error, phase: String, objectPath: String) -> String {
        let nsError = error as NSError
        let storageCode = StorageErrorCode(rawValue: nsError.code)
        let codeLabel: String
        let hint: String
        let bucket = (nsError.userInfo["bucket"] as? String) ?? "unknown-bucket"
        let object = (nsError.userInfo["object"] as? String) ?? objectPath
        let responseBody = (nsError.userInfo["ResponseBody"] as? String)
            ?? (nsError.userInfo["responseBody"] as? String)
            ?? "n/a"

        switch storageCode {
        case .unauthenticated:
            codeLabel = "unauthenticated"
            hint = "User is not signed in."
        case .unauthorized:
            codeLabel = "unauthorized"
            hint = "Check Firebase Storage rules for write access to /announcements/{imageId}."
        case .objectNotFound:
            codeLabel = "object-not-found"
            hint = "Object missing at requested path."
        case .quotaExceeded:
            codeLabel = "quota-exceeded"
            hint = "Firebase Storage quota exceeded."
        case .retryLimitExceeded:
            codeLabel = "retry-limit-exceeded"
            hint = "Network retry limit exceeded. Check connectivity."
        case .cancelled:
            codeLabel = "cancelled"
            hint = "Operation was cancelled."
        case .nonMatchingChecksum:
            codeLabel = "non-matching-checksum"
            hint = "Uploaded data checksum mismatch."
        default:
            codeLabel = "unknown"
            hint = "See underlying error details."
        }

        return "phase=\(phase) path=\(objectPath) bucket=\(bucket) object=\(object) code=\(codeLabel) message=\(nsError.localizedDescription) hint=\(hint) response=\(responseBody)"
    }

    func userFacingImageUploadError() -> String {
        guard let raw = lastImageStorageError, !raw.isEmpty else {
            return "Image upload failed. Please try again."
        }

        if raw.contains("code=unauthenticated") {
            return "Image upload failed because you are not signed in. Please sign in again."
        }
        if raw.contains("code=unauthorized") {
            return "Image upload is blocked by Firebase Storage rules."
        }
        if raw.contains("code=object-not-found") {
            return "Image upload failed due to Firebase Storage bucket/path configuration."
        }
        if raw.contains("code=quota-exceeded") {
            return "Image upload failed because Firebase Storage quota was exceeded."
        }

        return "Image upload failed. Please try again."
    }

    func firestoreInlineImageBase64(from originalImageData: Data) -> String? {
        #if canImport(UIKit)
        guard let image = UIImage(data: originalImageData) else { return nil }

        let maxDimension: CGFloat = 1200
        let resized = resizedImage(image, maxDimension: maxDimension)
        let qualities: [CGFloat] = [0.65, 0.5, 0.4, 0.3]
        let maxBytes = 320_000

        for quality in qualities {
            if let data = resized.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data.base64EncodedString()
            }
        }

        if let data = resized.jpegData(compressionQuality: 0.25) {
            return data.base64EncodedString()
        }
        return nil
        #else
        return nil
        #endif
    }

    #if canImport(UIKit)
    private func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let width = image.size.width
        let height = image.size.height
        guard width > 0, height > 0 else { return image }

        let longest = max(width, height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: width * scale, height: height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    #endif

    // MARK: - Auto-Cleanup Expired

    func cleanupExpired() async {
        do {
            let snapshot = try await db.collection("announcements")
                .whereField("expiresAt", isLessThan: Timestamp(date: Date()))
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                if data["imageURL"] as? String != nil {
                    await deleteImage(for: doc.documentID)
                }
                try await doc.reference.delete()
            }

            if !snapshot.documents.isEmpty {
                print("AnnouncementsManager: cleaned up \(snapshot.documents.count) expired announcements")
            }
        } catch {
            print("AnnouncementsManager cleanup error: \(error.localizedDescription)")
        }
    }

    /// Announcements expiring within 7 days
    var expiringSoon: [Announcement] {
        announcements.filter { $0.isExpiringSoon && !$0.isExpired }
    }
}
