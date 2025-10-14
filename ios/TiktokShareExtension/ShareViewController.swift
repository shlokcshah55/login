//
//  ShareViewController.swift
//  TiktokShareExtension
//
//  Created by Shlok Shah on 08/10/2025.
//

import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {

    private let appGroupName = "group.pinit.app"
    private let sharedURLKey = "shared_url"

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        // Extract the shared content
        if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem {
            if let itemProvider = extensionItem.attachments?.first {
                // Try URL first
                if itemProvider.hasItemConformingToTypeIdentifier("public.url") {
                    itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (url, error) in
                        if let shareURL = url as? URL {
                            self?.saveSharedURL(shareURL.absoluteString)
                        }
                        self?.completeRequest()
                    }
                    return
                }

                // Try plain text (TikTok sometimes shares as text)
                if itemProvider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    itemProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (text, error) in
                        if let shareText = text as? String {
                            self?.saveSharedURL(shareText)
                        }
                        self?.completeRequest()
                    }
                    return
                }
            }
        }

        // If we couldn't extract anything, just complete
        completeRequest()
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    private func saveSharedURL(_ url: String) {
        // Save to UserDefaults using App Groups
        if let userDefaults = UserDefaults(suiteName: appGroupName) {
            // Get existing URLs or create new array
            var urls = userDefaults.stringArray(forKey: sharedURLKey) ?? []
            urls.append(url)

            userDefaults.set(urls, forKey: sharedURLKey)
            userDefaults.synchronize()

            print("✅ Saved URL to UserDefaults: \(url)")
        } else {
            print("❌ Failed to access UserDefaults with app group: \(appGroupName)")
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
