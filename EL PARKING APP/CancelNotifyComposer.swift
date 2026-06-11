//
//  CancelNotifyComposer.swift
//  EL PARKING APP
//
//  Free, instant out-of-band notification when an admin cancels a booking:
//  opens the native Messages or Mail composer pre-filled. Works regardless
//  of whether the recipient's app is running — no push infrastructure.
//

import SwiftUI
import MessageUI

enum CancelNotify {
    static func body(spot: String, date: String, reason: String) -> String {
        var t = L10n.isCzech
            ? "Dobrý den, vaše rezervace parkovacího místa \(spot) na \(date) byla zrušena administrátorem."
            : "Hello, your booking for parking spot \(spot) on \(date) was cancelled by an administrator."
        if !reason.trimmingCharacters(in: .whitespaces).isEmpty {
            t += L10n.isCzech ? " Důvod: \(reason)" : " Reason: \(reason)"
        }
        return t
    }

    /// SMS via the sms: scheme (Messages app pre-filled).
    static func sendMessage(to phone: String, body: String) {
        let digits = phone.filter { "+0123456789".contains($0) }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        let encoded = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        if let url = URL(string: "sms:\(digits)&body=\(encoded)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    /// Email via mailto: (works without configuring MFMailComposeViewController).
    static func sendEmail(to email: String, subject: String, body: String) {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=#")
        let sub = subject.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        let bod = body.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        if let url = URL(string: "mailto:\(email)?subject=\(sub)&body=\(bod)") {
            UIApplication.shared.open(url)
        }
    }
}
