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
        print("===========================================")
        print("🔍 Share Extension: extractAndProcessSharedContent() called")
        print("🔍 Share Extension: Starting URL extraction...")
        print("===========================================")

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
        print("💾 Share Extension: Processing \(urls.count) URLs")
        print("💾 Share Extension: URLs array: \(urls)")

        guard !urls.isEmpty else {
            print("⚠️ Share Extension: No URLs found to process")
            DispatchQueue.main.async { [weak self] in
                self?.showError("No URL found to share")
            }
            return
        }

        // Get userId from App Group UserDefaults
        print("🔍 Share Extension: Attempting to access App Group UserDefaults")
        guard let userDefaults = UserDefaults(suiteName: "group.com.srishlok.pinit") else {
            print("❌ Share Extension: FAILED to access App Group UserDefaults!")
            DispatchQueue.main.async { [weak self] in
                self?.showError("Configuration error - cannot access app group")
            }
            return
        }

        print("✅ Share Extension: Successfully accessed App Group UserDefaults")

        guard let userId = userDefaults.string(forKey: "user_id") else {
            print("❌ Share Extension: No user ID found in App Group")
            print("🔍 Share Extension: Available keys in UserDefaults: \(userDefaults.dictionaryRepresentation().keys)")
            DispatchQueue.main.async { [weak self] in
                self?.showError("Please open Pinit and sign in first")
            }
            return
        }

        print("✅ Share Extension: Found user ID: \(userId)")
        print("🔗 Share Extension: Sharing URL: \(urls.first!)")

        // Send to backend
        sendToBackend(url: urls.first!, userId: userId)
    }

    private func sendToBackend(url: String, userId: String) {
        print("🚀 Share Extension: sendToBackend() called")
        print("🚀 Share Extension: URL parameter: \(url)")
        print("🚀 Share Extension: UserID parameter: \(userId)")

        // Show loading state (must be on main thread)
        DispatchQueue.main.async { [weak self] in
            self?.showLoading()
            print("⏳ Share Extension: Loading UI displayed")
        }

        // Create backend URL
        let backendURLString = "https://tiktok-processor-1070859807237.europe-west1.run.app/process-share"
        print("🔗 Share Extension: Backend URL: \(backendURLString)")

        guard let backendURL = URL(string: backendURLString) else {
            print("❌ Share Extension: Invalid backend URL")
            DispatchQueue.main.async { [weak self] in
                self?.showError("Configuration error")
            }
            return
        }
        print("✅ Share Extension: Backend URL created successfully")

        // Create request
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10 // 10 second timeout
        print("✅ Share Extension: HTTP request configured (POST, 10s timeout)")

        // Create request body
        let body: [String: Any] = [
            "url": url,
            "userId": userId
        ]
        print("📦 Share Extension: Request body: \(body)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("✅ Share Extension: Request body serialized to JSON")
        } catch {
            print("❌ Share Extension: Failed to encode request body: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.showError("Failed to prepare request")
            }
            return
        }

        print("📡 Share Extension: Sending HTTP request to backend NOW...")
        print("📡 Share Extension: Request details - URL: \(request.url?.absoluteString ?? "nil")")
        print("📡 Share Extension: Request details - Method: \(request.httpMethod ?? "nil")")
        print("📡 Share Extension: Request details - Headers: \(request.allHTTPHeaderFields ?? [:])")

        // Send request
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            print("📬 Share Extension: URLSession completion handler called")
            print("📬 Share Extension: Error object: \(String(describing: error))")
            print("📬 Share Extension: Response object: \(String(describing: response))")
            print("📬 Share Extension: Data received: \(data?.count ?? 0) bytes")

            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Share Extension: Network error detected")
                    print("❌ Share Extension: Error type: \(type(of: error))")
                    print("❌ Share Extension: Error description: \(error.localizedDescription)")
                    print("❌ Share Extension: Error debug description: \(error)")
                    self?.showError("Network error. Please try again.")
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ Share Extension: Response is not HTTPURLResponse")
                    print("❌ Share Extension: Response type: \(type(of: response))")
                    self?.showError("Invalid response from server")
                    return
                }

                print("📡 Share Extension: HTTPURLResponse received")
                print("📡 Share Extension: Status code: \(httpResponse.statusCode)")
                print("📡 Share Extension: Headers: \(httpResponse.allHeaderFields)")

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("📡 Share Extension: Response body: \(responseString)")
                }

                if httpResponse.statusCode == 200 || httpResponse.statusCode == 202 {
                    // Success - backend is processing
                    print("✅ Share Extension: Backend accepted the request (status \(httpResponse.statusCode))")
                    self?.showSuccess()
                } else {
                    // Error response
                    print("⚠️ Share Extension: Backend returned error status code: \(httpResponse.statusCode)")
                    self?.handleErrorResponse(data: data, statusCode: httpResponse.statusCode)
                }
            }
        }

        print("🔄 Share Extension: Calling task.resume() to start the request")
        task.resume()
        print("✅ Share Extension: task.resume() called - request is now in flight")
    }

    private func handleErrorResponse(data: Data?, statusCode: Int) {
        print("⚠️ Share Extension: handleErrorResponse called with status \(statusCode)")
        var errorMessage = "Failed to process TikTok"

        if let data = data {
            print("⚠️ Share Extension: Parsing error response data (\(data.count) bytes)")
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("⚠️ Share Extension: Error JSON: \(json)")
                if let error = json["error"] as? String {
                    errorMessage = error
                }
            }
        } else {
            errorMessage = "Server error (\(statusCode))"
        }

        print("❌ Share Extension: Final error message: \(errorMessage)")
        showError(errorMessage)
    }

    private func showLoading() {
        print("⏳ Share Extension: showLoading() called")
        // Add a simple loading indicator to the view
        let loadingLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        loadingLabel.center = view.center
        loadingLabel.textAlignment = .center
        loadingLabel.text = "Sharing..."
        loadingLabel.textColor = .label
        loadingLabel.tag = 999 // Tag for later removal
        view.addSubview(loadingLabel)

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = CGPoint(x: view.center.x, y: view.center.y - 40)
        activityIndicator.tag = 998
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        print("✅ Share Extension: Loading UI added to view")
    }

    private func removeLoading() {
        print("🗑️ Share Extension: removeLoading() called")
        view.viewWithTag(999)?.removeFromSuperview()
        view.viewWithTag(998)?.removeFromSuperview()
    }

    private func showSuccess() {
        print("🎉 Share Extension: showSuccess() called")
        removeLoading()

        // Create card popover
        let successCard = createSuccessCard()
        view.addSubview(successCard)

        // Fade in with scale
        successCard.alpha = 0
        successCard.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseOut) {
            successCard.alpha = 1
            successCard.transform = .identity
        }

        // Progress bar animation removed - button stays static

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.dismissSuccessCard(successCard)
        }

        print("✅ Share Extension: Success card displayed")
    }

    private func createSuccessCard() -> UIView {
        let cardWidth: CGFloat = 320
        let cardHeight: CGFloat = 240

        // Card container
        let card = UIView(frame: CGRect(x: (view.bounds.width - cardWidth) / 2,
                                       y: (view.bounds.height - cardHeight) / 2,
                                       width: cardWidth,
                                       height: cardHeight))
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.3
        card.layer.shadowOffset = CGSize(width: 0, height: 10)
        card.layer.shadowRadius = 20

        // Background image view
        let backgroundImageView = UIImageView(frame: card.bounds)
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true

        // Try to load background.jpg from share extension bundle
        if let image = UIImage(named: "background.jpg") {
            backgroundImageView.image = image
            print("✅ Share Extension: Loaded background.jpg")
        } else {
            // Fallback to solid purple color
            backgroundImageView.backgroundColor = UIColor(red: 0.259, green: 0.078, blue: 0.239, alpha: 1.0) // #42143d
            print("⚠️ Share Extension: background.jpg not found, using solid color")
        }
        card.addSubview(backgroundImageView)

        // Semi-transparent overlay for better text readability
        let overlay = UIView(frame: card.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        card.addSubview(overlay)

        // Message label
        let messageLabel = UILabel()
        messageLabel.text = "Pinning this location...,\nwe will let you know when you are done"
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(messageLabel)

        // Button container (static, no progress effect)
        let buttonHeight: CGFloat = 50
        let buttonWidth: CGFloat = 220

        let buttonContainer = UIView()
        buttonContainer.backgroundColor = .white
        buttonContainer.layer.cornerRadius = 25
        buttonContainer.clipsToBounds = true
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(buttonContainer)

        // Button label on top
        let buttonLabel = UILabel()
        buttonLabel.text = "OK"
        buttonLabel.textAlignment = .center
        buttonLabel.textColor = UIColor(red: 0.259, green: 0.078, blue: 0.239, alpha: 1.0) // #42143d
        buttonLabel.font = UIFont.boldSystemFont(ofSize: 16)
        buttonLabel.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(buttonLabel)

        // Tap gesture for button
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(successCardTapped(_:)))
        buttonContainer.addGestureRecognizer(tapGesture)

        // Layout constraints
        NSLayoutConstraint.activate([
            // Message label
            messageLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -40),
            messageLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 30),
            messageLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -30),

            // Button container
            buttonContainer.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            buttonContainer.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 35),
            buttonContainer.widthAnchor.constraint(equalToConstant: buttonWidth),
            buttonContainer.heightAnchor.constraint(equalToConstant: buttonHeight),

            // Button label - centered on button
            buttonLabel.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            buttonLabel.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor)
        ])

        return card
    }

    private func animateProgressBar(_ progressView: UIView) {
        guard let buttonContainer = progressView.superview else { return }

        // Deactivate initial width constraint
        progressView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                constraint.isActive = false
            }
        }

        // Create new constraint for full width
        let fullWidthConstraint = progressView.widthAnchor.constraint(equalTo: buttonContainer.widthAnchor)
        fullWidthConstraint.isActive = true

        // Animate to full width over 3 seconds
        UIView.animate(withDuration: 3.0, delay: 0, options: .curveLinear) {
            buttonContainer.layoutIfNeeded()
        }
    }

    @objc private func successCardTapped(_ sender: UITapGestureRecognizer) {
        print("👆 Share Extension: User tapped success button")
        if let buttonContainer = sender.view,
           let card = buttonContainer.superview {
            dismissSuccessCard(card)
        }
    }

    private func dismissSuccessCard(_ card: UIView) {
        print("🔚 Share Extension: Dismissing success card")
        UIView.animate(withDuration: 0.3, animations: {
            card.alpha = 0
            card.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { [weak self] _ in
            card.removeFromSuperview()
            self?.closeExtension()
        }
    }

    private func showError(_ message: String) {
        print("❌ Share Extension: showError() called with message: \(message)")
        removeLoading()

        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            print("🔚 Share Extension: User dismissed error alert, closing extension")
            self?.closeExtension()
        })

        print("📱 Share Extension: Presenting error alert")
        present(alert, animated: true)
    }

    private func closeExtension() {
        print("🔚 Share Extension: closeExtension() called - completing request")
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        print("✅ Share Extension: Extension request completed")
    }

}
