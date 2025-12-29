//
//  ShareViewController.swift
//  URLShareExtension
//
//  Created by Shlok Shah on 24/10/2025.
//

import UIKit

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        print("🚀 Share Extension: viewDidLoad() called")

        // Immediately extract and process shared content
        extractAndProcessSharedContent()
    }

    private func extractAndProcessSharedContent() {
        print("🔍 Share Extension: Extracting shared content...")

        guard let extensionContext = self.extensionContext,
              let inputItems = extensionContext.inputItems as? [NSExtensionItem] else {
            print("⚠️ Share Extension: No extension context or input items")
            closeExtension()
            return
        }

        print("📦 Share Extension: Found \(inputItems.count) input items")

        var sharedURLs: [String] = []
        var processedCount = 0
        var totalProviders = 0

        // Count total providers to know when we're done
        for item in inputItems {
            if let attachments = item.attachments {
                totalProviders += attachments.count
                print("📎 Share Extension: Item has \(attachments.count) attachments")
            }
        }

        guard totalProviders > 0 else {
            print("⚠️ Share Extension: No providers to process")
            closeExtension()
            return
        }

        print("🔢 Share Extension: Processing \(totalProviders) providers")

        // Extract content from all providers
        for item in inputItems {
            if let attachments = item.attachments {
                for provider in attachments {
                    print("🔍 Share Extension: Provider registered type identifiers: \(provider.registeredTypeIdentifiers)")
                    
                    // Handle URLs
                    if provider.hasItemConformingToTypeIdentifier("public.url") {
                        provider.loadItem(forTypeIdentifier: "public.url", options: nil) { (item, error) in
                            if let error = error {
                                print("❌ Share Extension: Error loading URL: \(error)")
                            }
                            if let url = item as? URL {
                                sharedURLs.append(url.absoluteString)
                                print("📎 Share Extension: Found URL: \(url.absoluteString)")
                            }

                            processedCount += 1
                            if processedCount == totalProviders {
                                self.saveAndOpenApp(urls: sharedURLs)
                            }
                        }
                    }
                    // Handle text (in case URL is shared as text)
                    else if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                        provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { (item, error) in
                            if let error = error {
                                print("❌ Share Extension: Error loading text: \(error)")
                            }
                            if let text = item as? String {
                                sharedURLs.append(text)
                                print("📎 Share Extension: Found text: \(text)")
                            }

                            processedCount += 1
                            if processedCount == totalProviders {
                                self.saveAndOpenApp(urls: sharedURLs)
                            }
                        }
                    }
                    else {
                        // Not a supported type, just increment counter
                        print("⚠️ Share Extension: Unsupported type, skipping")
                        processedCount += 1
                        if processedCount == totalProviders {
                            self.saveAndOpenApp(urls: sharedURLs)
                        }
                    }
                }
            }
        }
    }

    private func saveAndOpenApp(urls: [String]) {
        print("💾 Share Extension: saveAndOpenApp called with \(urls.count) URLs")

        guard !urls.isEmpty else {
            print("⚠️ Share Extension: No URLs found to process")
            closeExtension()
            return
        }

        print("🔗 Share Extension: URLs to save: \(urls)")

        // Save to App Group UserDefaults (replace, don't append)
        if let userDefaults = UserDefaults(suiteName: "group.sriharsha.srishlok.pinit") {
            // Replace any existing URLs with the new ones
            userDefaults.set(urls, forKey: "shared_url")
            userDefaults.synchronize()

            print("✅ Share Extension: Saved \(urls.count) URL(s) to App Group (replaced any existing)")
        } else {
            print("❌ Share Extension: FAILED to access App Group UserDefaults!")
        }

        // Open the main app via URL scheme
        openMainApp()
    }

    private func openMainApp() {
        guard let url = URL(string: "pinit://share") else {
            print("⚠️ Share Extension: Invalid URL scheme")
            closeExtension()
            return
        }

        // Use the modern iOS extension API to open the main app
        self.extensionContext?.open(url, completionHandler: { [weak self] success in
            if success {
                print("📲 Share Extension: Successfully opened main app")
            } else {
                print("⚠️ Share Extension: Failed to open main app - check URL scheme registration")
            }

            // Delay closing the extension to give the main app time to launch
            // This prevents the extension from closing before the app has fully started
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔚 Share Extension: Closing extension")
                self?.closeExtension()
            }
        })
    }

    private func closeExtension() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

}
