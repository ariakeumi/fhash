//
//  AboutViewController.swift
//  fHash
//
//  Created by Sun Junwen on 2023/12/5.
//  Copyright © 2023 Sun Junwen. All rights reserved.
//

import Cocoa

@objc(AboutViewController) class AboutViewController: NSViewController {
    @IBOutlet weak var mainView: NSView!
    @IBOutlet weak var iconImageView: NSImageView!
    @IBOutlet weak var infoTextField: NSTextField!
    @IBOutlet weak var homePageLinkTextField: HyperlinkTextField!
    @IBOutlet weak var closeButton: NSButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup NSVisualEffectView/NSGlassEffectView background.
        _ = MacSwiftUtils.SetupEffectViewBackground(mainView)
        configureAboutChrome()

        // Do view setup here.
        iconImageView.image = NSApp.applicationIconImage

        let strAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let strAppBundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        var strAboutInfo = ""
        strAboutInfo += MacSwiftUtils.GetStringFromRes("ABOUTDLG_INFO_RIGHT")
        strAboutInfo += "\n"
        strAboutInfo += "\n"
        strAboutInfo += MacSwiftUtils.GetStringFromRes("ABOUTDLG_INFO_MD5")
        strAboutInfo += "\n"
        strAboutInfo += MacSwiftUtils.GetStringFromRes("ABOUTDLG_INFO_SHA256")
        infoTextField.attributedStringValue = buildAboutInfoText(
            version: strAppVersion ?? "",
            build: strAppBundleVersion ?? "",
            details: strAboutInfo
        )

        // Set homepage.
        var strLinkText = MacSwiftUtils.GetStringFromRes("ABOUTDLG_PROJECT_SITE")
        strLinkText = strLinkText.replacingOccurrences(of: "<a>", with: "")
        strLinkText = strLinkText.replacingOccurrences(of:"</a>", with: "")
        let url = URL(string: MacSwiftUtils.GetStringFromRes("ABOUTDLG_PROJECT_URL"))!
        let hyperlinkString = NSMutableAttributedString(
            string: strLinkText)
        hyperlinkString.beginEditing()
        hyperlinkString.addAttribute(
            .link,
            value: url,
            range: NSRange(location: 0, length: hyperlinkString.length))
        hyperlinkString.addAttribute(
            .foregroundColor,
            value: NSColor.controlAccentColor,
            range: NSRange(location: 0, length: hyperlinkString.length))
        hyperlinkString.addAttribute(
            .font,
            value: NSFont.systemFont(ofSize: 13),
            range: NSRange(location: 0, length: hyperlinkString.length))
        hyperlinkString.endEditing()

        homePageLinkTextField.attributedStringValue = hyperlinkString

        closeButton.keyEquivalent = "\r"
        closeButton.title = MacSwiftUtils.GetStringFromRes("BUTTON_OK")
        closeButton.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        closeButton.bezelColor = nil
        closeButton.contentTintColor = nil
        if (MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
            closeButton.controlSize = .regular
        }
    }

    @IBAction func closeButtonClicked(_ sender: NSButton) {
        view.window?.close()
    }

    private func configureAboutChrome() {
        iconImageView.wantsLayer = false
        iconImageView.imageScaling = .scaleProportionallyUpOrDown

        infoTextField.maximumNumberOfLines = 0
        infoTextField.lineBreakMode = .byWordWrapping
    }

    private func buildAboutInfoText(version: String, build: String, details: String) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let versionText: String
        if version.isEmpty {
            versionText = "fHash"
        } else if build.isEmpty {
            versionText = "fHash \(version)"
        } else {
            versionText = "fHash \(version) (\(build))"
        }

        let title = NSMutableAttributedString(
            string: "\(versionText)\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 19, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 4

        let body = NSMutableAttributedString(
            string: details,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        text.append(title)
        text.append(body)

        return text
    }
}
