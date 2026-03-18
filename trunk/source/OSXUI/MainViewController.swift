//
//  MainViewController.swift
//  fHash
//
//  Created by Sun Junwen on 2023/12/6.
//  Copyright © 2023 Sun Junwen. All rights reserved.
//

import Cocoa

let UpperCaseDefaultKey = "upperCaseKey"
let FindBarAtBelowAfter26 = true

private struct MainViewControllerState: OptionSet {
    let rawValue: Int

    static let NONE = MainViewControllerState(rawValue: 1 << 0) // clear state
    static let CALC_ING = MainViewControllerState(rawValue: 1 << 1) // calculating
    static let CALC_FINISH = MainViewControllerState(rawValue: 1 << 2) // calculating finished/stopped
    static let VERIFY = MainViewControllerState(rawValue: 1 << 3) // verfing
    static let WAITING_EXIT = MainViewControllerState(rawValue: 1 << 4) // waiting thread stop and exit
}

private enum HashComparisonOutcome {
    case same
    case different

    var foregroundColor: NSColor {
        switch self {
        case .same:
            return .systemGreen
        case .different:
            return .systemRed
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .same:
            return NSColor.systemGreen.withAlphaComponent(0.14)
        case .different:
            return NSColor.systemRed.withAlphaComponent(0.14)
        }
    }
}

private struct MultiFileComparisonState {
    let md5MatchedValues: Set<String>
    let sha256MatchedValues: Set<String>

    func outcome(for name: String, hashValue: String) -> HashComparisonOutcome {
        let normalizedHashValue = hashValue.lowercased()
        let isMatched = (name == "MD5")
            ? md5MatchedValues.contains(normalizedHashValue)
            : sha256MatchedValues.contains(normalizedHashValue)
        return isMatched ? .same : .different
    }
}

@objc(MainViewController) class MainViewController: NSViewController, NSTextViewDelegate, NSSearchFieldDelegate {
    static let MainClipViewInsetAfter26 = NSEdgeInsets(top: 28, left: 0, bottom: 0, right: 0)
    static let MainClipViewInsetWithFindBarAtAboveAfter26 = NSEdgeInsets(top: 34, left: 0, bottom: 0, right: 0)
    static let MainClipViewInsetWithFindBarAtBelowAfter26 = NSEdgeInsets(top: 28, left: 0, bottom: 26, right: 0)
    static let MainTextViewInsetAfter26 = NSMakeSize(3.0, 2.0)
    static let MainScrollViewTopConstraintAfter26: CGFloat = 26

    @IBOutlet weak var mainScrollView: MainScrollView!
    @IBOutlet weak var mainScrollViewTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var mainClipView: PaddingClipView!

    @IBOutlet weak var mainTextView: NSTextView!

    @IBOutlet weak var mainProgressIndicator: NSProgressIndicator!

    @IBOutlet weak var openButton: NSButton!
    @IBOutlet weak var clearButton: NSButton!
    @IBOutlet weak var verifyButton: NSButton!

    @IBOutlet weak var upperCaseButton: NSButton!

    @IBOutlet weak var speedTextField: NSTextField!

    @objc var tag: Int = 0 // Must have @ojbc, it is used to open finder bar.

    private var mainText: NSMutableAttributedString?
    private var nsAttrStrNoPreparing: NSAttributedString?

    private var state: MainViewControllerState = .NONE

    private var mainFont: NSFont?

    private var selectedLink: String = ""

    private var calcStartTime: UInt64 = 0
    private var calcEndTime: UInt64 = 0

    private var upperCaseState = false

    private var inMainQueue: Int = 0
    private var outMainQueue: Int = 0
    private let maxDiffQueue = 3

    private var curFindPanelVisible = false

    private var hashBridge: HashBridge?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let fHashDelegate = NSApp.delegate as? fHashMacAppDelegate

        // Initiate.
        fHashDelegate?.mainViewController = self

        let mainView = view as! MainView
        mainView.mainViewController = self
        mainScrollView.mainViewController = self
        mainClipView.mainViewController = self

        mainClipView.postsBoundsChangedNotifications = true

        // Setup NSVisualEffectView/NSGlassEffectView background.
        _ = MacSwiftUtils.SetupEffectViewBackground(mainView)

        // Register NSUserDefaults.
        let defaultsDictionary = [
            UpperCaseDefaultKey: Bool(false)
        ]
        UserDefaults.standard.register(defaults: defaultsDictionary)

        // Load NSUserDefaults.
        let defaultUpperCase = UserDefaults.standard.bool(forKey: UpperCaseDefaultKey)

        // Alloc bridge.
        hashBridge = HashBridge(controller: self)
        hashBridge?.didLoad()

        // Set DockProgress.
        DockProgress.style = .bar

        self.setViewControllerState(.NONE)

        let fileMenu = self.getFileMenu()
        fileMenu?.autoenablesItems = false

        // Set buttons title.
        verifyButton.title = MacSwiftUtils.GetStringFromRes("MAINDLG_VERIFY")
        upperCaseButton.title = MacSwiftUtils.GetStringFromRes("MAINDLG_UPPER_HASH")

        // Set open button as default.
        openButton.keyEquivalent = "\r"

        curFindPanelVisible = mainScrollView.isFindBarVisible

        // Set scroll view border type.
        mainScrollView.borderType = .noBorder

        // Set scroll view findbar position.
        if (MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
            mainScrollView.findBarPosition = .belowContent
        } else {
            if FindBarAtBelowAfter26 {
                mainScrollView.findBarPosition = .belowContent
            } else {
                mainScrollView.findBarPosition = .aboveContent
            }
        }

        // Set clip view insets.
        if (!MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
            mainClipView.automaticallyAdjustsContentInsets = false
            mainClipView.contentInsets = MainViewController.MainClipViewInsetAfter26
        }

        // Set some text in text field.
        mainTextView.delegate = self
        if (MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
            mainTextView.textContainerInset = NSMakeSize(3.0, 2.0)
        } else {
            mainTextView.textContainerInset = MainViewController.MainTextViewInsetAfter26
        }

        mainFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
        if mainFont == nil {
            mainFont = mainTextView.font
        }
        mainTextView.font = mainFont

        mainTextView.usesFindBar = true

        // Set TextView nowrap.
        mainTextView.enclosingScrollView?.hasHorizontalScroller = true
        mainTextView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        mainTextView.isHorizontallyResizable = true
        mainTextView.autoresizingMask = [.width, .height]
        mainTextView.textContainer?.containerSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        mainTextView.textContainer?.widthTracksTextView = false

        // Set TextView word wrap.
        // let contentSize = mainScrollView.contentSize
        // mainTextView.enclosingScrollView?.hasHorizontalScroller = false
        // mainTextView.minSize = NSMakeSize(0.0, contentSize.height)
        // mainTextView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
        // mainTextView.isVerticallyResizable = true
        // mainTextView.isHorizontallyResizable = false
        // mainTextView.autoresizingMask = .width
        // mainTextView.textContainer?.containerSize = NSMakeSize(contentSize.width, CGFloat.greatestFiniteMagnitude)
        // mainTextView.textContainer?.widthTracksTextView = true

        // Set progressbar.
        let mainProgIndiFrame = mainProgressIndicator.frame
        mainProgressIndicator.setFrameSize(NSMakeSize(mainProgIndiFrame.size.width, 10))
        mainProgressIndicator.maxValue = Double(hashBridge!.getProgMax())

        // Set checkbox.
        if defaultUpperCase {
            upperCaseButton.state = .on
        } else {
            upperCaseButton.state = .off
        }
        self.updateUpperCaseState()

        // Update main text.
        self.updateMainTextView()
        self.configureBeautifulInterface()
    }

    override func viewWillDisappear() {
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }

    func viewWillClose() {
        DockProgress.resetProgress()

        // Save NSUserDefaults.
        let defaultUpperCase = (upperCaseButton.state == .on)
        UserDefaults.standard.set(
            defaultUpperCase,
            forKey: UpperCaseDefaultKey)
    }

    private func configureBeautifulInterface() {
        mainScrollViewTopConstraint.constant = 0
        mainScrollView.borderType = .bezelBorder
        mainScrollView.drawsBackground = true
        mainScrollView.backgroundColor = .textBackgroundColor
        mainScrollView.wantsLayer = false

        configureTextSurface()
        configureButtons()
        configureSpeedField()
        refreshActionButtonStyles()
        updateMainTextView(true)
    }

    private func configureTextSurface() {
        mainClipView.wantsLayer = false

        mainTextView.drawsBackground = true
        mainTextView.backgroundColor = .textBackgroundColor
        mainTextView.insertionPointColor = .controlAccentColor
        mainTextView.linkTextAttributes = [
            .foregroundColor: NSColor.controlAccentColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        mainTextView.textContainerInset = NSMakeSize(10.0, 12.0)

        mainFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
        if mainFont == nil {
            mainFont = mainTextView.font
        }
        mainTextView.font = mainFont
    }

    private func configureButtons() {
        [openButton, clearButton, verifyButton].forEach { button in
            button.image = nil
            button.imagePosition = .noImage
            button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            button.controlSize = .regular
            button.focusRingType = .default
            button.bezelColor = nil
            button.contentTintColor = nil
            button.alphaValue = 1.0
        }

        upperCaseButton.image = nil
        upperCaseButton.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        upperCaseButton.contentTintColor = nil
        upperCaseButton.alphaValue = 1.0
        upperCaseButton.focusRingType = .default
    }

    private func configureSpeedField() {
        speedTextField.isBordered = false
        speedTextField.drawsBackground = false
        speedTextField.wantsLayer = false
        speedTextField.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        speedTextField.alignment = .right
        speedTextField.textColor = .secondaryLabelColor
        updateSpeedFieldAppearance()
    }

    private func refreshActionButtonStyles() {
        [openButton, clearButton, verifyButton].forEach { button in
            button.bezelColor = nil
            button.contentTintColor = nil
            button.alphaValue = 1.0
        }

        upperCaseButton.contentTintColor = nil
        upperCaseButton.alphaValue = 1.0

        updateSpeedFieldAppearance()
    }

    private func updateSpeedFieldAppearance() {
        let hasValue = !speedTextField.stringValue.isEmpty
        speedTextField.isHidden = !hasValue
        speedTextField.alphaValue = hasValue ? 1.0 : 0.0
    }

    private func setViewControllerState(_ newState: MainViewControllerState) {
        switch newState {
        case .NONE:
            // Clear all.
            hashBridge?.clear()

            mainText = NSMutableAttributedString()
            var strAppend = MacSwiftUtils.GetStringFromRes("MAINDLG_INITINFO")
            strAppend += "\n\n"
            MacSwiftUtils.AppendStringToNSMutableAttributedString(mainText, strAppend)

            mainProgressIndicator.doubleValue = 0
            DockProgress.resetProgress()

            speedTextField.stringValue = ""

            // Passthrough to MAINVC_CALC_FINISH.
            fallthrough
        case .CALC_FINISH:
            calcEndTime = MacSwiftUtils.GetCurrentMilliSec()

            // Set controls title.
            let openMenuItem = self.getOpenMenuItem()
            openMenuItem?.isEnabled = true

            openButton.title = MacSwiftUtils.GetStringFromRes("MAINDLG_OPEN")
            clearButton.title = MacSwiftUtils.GetStringFromRes("MAINDLG_CLEAR")
            clearButton.isEnabled = true
            verifyButton.isEnabled = true
            upperCaseButton.isEnabled = true
        case .CALC_ING:
            calcStartTime = MacSwiftUtils.GetCurrentMilliSec()

            hashBridge?.setStop(false)

            let openMenuItem = self.getOpenMenuItem()
            openMenuItem?.isEnabled = false

            speedTextField.stringValue = ""

            openButton.title = MacSwiftUtils.GetStringFromRes("MAINDLG_STOP")
            clearButton.isEnabled = false
            verifyButton.isEnabled = false
            upperCaseButton.isEnabled = false

            self.bringWindowToFront()
        // case .VERIFY:
        // case .WAITING_EXIT:
        default:
            break
        }

        let oldState = state
        state = newState

        if state == .CALC_FINISH && oldState == .WAITING_EXIT {
            // User want to close.
            view.window?.close()
        }

        refreshActionButtonStyles()
    }

    private func getFileMenu() -> NSMenu? {
        let mainMenu = NSApp.mainMenu
        let fileMenuItem = mainMenu?.item(at: 1)
        return fileMenuItem?.submenu
    }

    private func getOpenMenuItem() -> NSMenuItem? {
        let mainMenu = NSApp.mainMenu
        let fileMenuItem = mainMenu?.item(at: 1)
        let openMenuItem = fileMenuItem?.submenu?.item(at: 0)
        return openMenuItem
    }

    func ableToCalcFiles() -> Bool {
        return !self.isCalculating()
    }

    func isCalculating() -> Bool {
        return (state == .CALC_ING || state == .WAITING_EXIT)
    }

    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = true

        openPanel.beginSheetModal(for: view.window!) { result in
            if result == .OK {
                let fileNames = openPanel.urls
                self.startHashCalc(fileNames, isURL: true)
            }
        }
    }

    func performViewDragOperation(_ sender: NSDraggingInfo?) {
        if let pboard = sender?.draggingPasteboard {
            let fileNames = pboard.readObjects(forClasses: [NSURL.self], options: [:])
            self.startHashCalc(fileNames ?? [], isURL: true)
        }
    }

    private func updateUpperCaseState() {
        upperCaseState = (upperCaseButton.state == .on)
    }

    private func updateMainTextView(_ keepScrollPosition: Bool) {
        // Apply style to all text.
        mainText?.beginEditing()

        mainText?.addAttribute(
            .font,
            value: mainFont as Any,
            range: NSRange(location: 0, length: mainText!.length))

        mainText?.addAttribute(
            .foregroundColor,
            value: NSColor.textColor,
            range: NSRange(location: 0, length: mainText!.length))

        // word wrap
        // var paraStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        // paraStyle.lineBreakMode = .byCharWrapping
        // mainText?.addAttribute(
        //     .paragraphStyle,
        //     value: paraStyle,
        //     range: NSRange(location: 0, length: mainText!.length))

        mainText?.endEditing()

        mainTextView.textStorage?.setAttributedString(mainText!)

        if (!MacSwiftUtils.IsSystemEarlierThan(14, 0) &&
            MacSwiftUtils.IsSystemEarlierThan(15, 3)) {
            // Sonoma and later insets fix.
            let fixInset = 5.0
            let mainTextSize = mainText!.size()
            let mainScrollViewSize = mainScrollView.frame.size
            var scrollViewContentInsets = mainScrollView.contentInsets
            var scrollViewScrollerInsets: NSEdgeInsets?
            if mainTextSize.width > mainScrollViewSize.width {
                // Add inset.
                scrollViewContentInsets.left = fixInset
                scrollViewContentInsets.right = fixInset
                scrollViewScrollerInsets = mainScrollView.scrollerInsets
                scrollViewScrollerInsets?.left = -(fixInset)
                scrollViewScrollerInsets?.right = -(fixInset)
            } else {
                // Reset inset.
                scrollViewContentInsets.left = 0
                scrollViewContentInsets.right = 0
                scrollViewScrollerInsets = mainScrollView.scrollerInsets
                scrollViewScrollerInsets?.left = 0
                scrollViewScrollerInsets?.right = 0
            }
            mainScrollView.contentInsets = scrollViewContentInsets
            mainScrollView.scrollerInsets = scrollViewScrollerInsets!
        }

        if !keepScrollPosition {
            // Scroll to end.
            mainTextView.layoutManager?.ensureLayout(for: mainTextView.textContainer!)
            mainTextView.scrollRangeToVisible(NSRange(location: mainTextView.string.count,
                                                      length: 0))

            // Keep on the left.
            if let enclosingScrollView = mainTextView.enclosingScrollView {
                enclosingScrollView.contentView.scroll(to:NSPoint(
                    x: 0, y: enclosingScrollView.contentView.bounds.origin.y))
                enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
            }
        }
    }

    private func updateMainTextView() {
        self.updateMainTextView(false)
    }

    private func canUpdateMainTextView() -> Bool {
        // NSLog("%@", ((self.inMainQueue - self.outMainQueue < self.maxDiffQueue) ? "true" : "false"))
        return (self.inMainQueue - self.outMainQueue < self.maxDiffQueue)
    }

    func findPanelVisibleChange(isVisible: Bool) {
        if (MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
            return
        }

        if FindBarAtBelowAfter26 {
            if isVisible {
                // show
                mainClipView.contentInsets = MainViewController.MainClipViewInsetWithFindBarAtBelowAfter26
            } else {
                // hide
                mainClipView.contentInsets = MainViewController.MainClipViewInsetAfter26
            }
        } else {
            if isVisible {
                // show
                mainScrollViewTopConstraint.constant = MainViewController.MainScrollViewTopConstraintAfter26
                mainClipView.contentInsets = MainViewController.MainClipViewInsetWithFindBarAtAboveAfter26
            } else {
                // hide
                mainScrollViewTopConstraint.constant = 0
                mainClipView.contentInsets = MainViewController.MainClipViewInsetAfter26
            }
        }

        // if let enclosingScrollView = mainTextView.enclosingScrollView {
        //     NSLog("findPanelVisibleChange, y=%.2f", enclosingScrollView.contentView.bounds.origin.y)
        // }

    }

    func clipViewSizeChange() {
        if (MacSwiftUtils.IsSystemEarlierThan(26, 0) ||
            FindBarAtBelowAfter26) {
            return
        }

        var scrollNeedFix = true
        var becameShow = true

        let newFindPanelVisible = mainScrollView.isFindBarVisible
        if newFindPanelVisible == curFindPanelVisible {
            scrollNeedFix = false
        }
        if newFindPanelVisible && !curFindPanelVisible {
            // show find bar
            // NSLog("clipViewSizeChange, show find bar")
        }
        if !newFindPanelVisible && curFindPanelVisible {
            // hide find bar
            // NSLog("clipViewSizeChange, hide find bar")
            becameShow = false
        }

        let mainTextSize = mainText!.size()
        let mainScrollViewSize = mainScrollView.frame.size
        // NSLog("clipViewSizeChange, mainTextSize.height=%.2f, mainScrollViewSize.height=%.2f",
        //       mainTextSize.height, mainScrollViewSize.height)
        if mainTextSize.height < mainScrollViewSize.height {
            scrollNeedFix = false
        }

        if scrollNeedFix, let enclosingScrollView = self.mainTextView.enclosingScrollView {
            // NSLog("clipViewSizeChange, y=%.2f", enclosingScrollView.contentView.bounds.origin.y)
            var scrollFix: CGFloat = 0
            let bottomOffset = mainTextSize.height - mainScrollViewSize.height - enclosingScrollView.contentView.bounds.origin.y
            if becameShow && enclosingScrollView.contentView.bounds.origin.y < -18 {
                // NSLog("clipViewSizeChange, fix show top")
                scrollFix = -6
            }
            // NSLog("clipViewSizeChange, bottomOffset=%.2f", bottomOffset)
            if becameShow && bottomOffset <= MainViewController.MainScrollViewTopConstraintAfter26 {
                // NSLog("clipViewSizeChange, fix show bottom")
                scrollFix = MainViewController.MainScrollViewTopConstraintAfter26
            }

            if scrollFix != 0 {
                enclosingScrollView.contentView.scroll(to:NSPoint(
                    x: enclosingScrollView.contentView.bounds.origin.x,
                    y: enclosingScrollView.contentView.bounds.origin.y + scrollFix))
                enclosingScrollView.reflectScrolledClipView(enclosingScrollView.contentView)
            }
            // NSLog("clipViewSizeChange, after, y=%.2f", enclosingScrollView.contentView.bounds.origin.y)
        }

        curFindPanelVisible = newFindPanelVisible
    }

    private func calculateFinished() {
        self.setViewControllerState(.CALC_FINISH)

        let progMax = hashBridge!.getProgMax()
        self.mainProgressIndicator.doubleValue = Double(progMax)
        self.updateDockProgress(Int(progMax))

        // Show calc speed.
        let calcDurationTime = calcEndTime - calcStartTime
        if calcDurationTime > 10 {
            // speed is Bytes/ms
            var calcSpeed = Double(hashBridge!.getTotalSize()) / Double(calcDurationTime)
            calcSpeed = calcSpeed * 1000 // Bytes/s

            var strSpeed = ""
            strSpeed = MacSwiftUtils.ConvertSizeToShortSizeStr(UInt64(calcSpeed), true)
            if strSpeed != "" {
                strSpeed += "/s"
            }
            speedTextField.stringValue = strSpeed
        } else {
            speedTextField.stringValue = ""
        }
        updateSpeedFieldAppearance()
    }

    private func calculateStopped() {
        let strAppend = "\n"
        //strAppend += MacSwiftUtils.GetStringFromRes("MAINDLG_CALCU_TERMINAL")
        //strAppend += "\n\n"

        MacSwiftUtils.AppendStringToNSMutableAttributedString(self.mainText, strAppend)

        self.setViewControllerState(.CALC_FINISH)

        self.mainProgressIndicator.doubleValue = 0
        DockProgress.resetProgress()

        //self.updateMainTextView()
    }

    func startHashCalc(_ fileNames: [Any], isURL: Bool) {
        if !self.ableToCalcFiles() {
            return
        }

        if state == .NONE {
            // Clear up text.
            mainText = NSMutableAttributedString()
        }

        // Get files path.
        hashBridge?.addFiles(fileNames, isURL: isURL)

        // Uppercase.
        self.updateUpperCaseState()
        hashBridge?.setUppercase(upperCaseState)

        mainProgressIndicator.doubleValue = 0
        DockProgress.resetProgress()

        self.setViewControllerState(.CALC_ING)

        // Ready to go.
        inMainQueue = 0
        outMainQueue = 0
        hashBridge?.startHashThread()
    }

    func stopHashCalc(_ needExit: Bool) {
        if state == .CALC_ING {
            hashBridge?.setStop(true)

            if needExit {
                self.setViewControllerState(.WAITING_EXIT)
            }
        }
    }

    private func refreshResultText() {
        self.updateUpperCaseState()

        mainText = NSMutableAttributedString()

        let results:[Any] = hashBridge!.getResults()
        let comparisonState = getMultiFileComparisonState(from: results)
        for result in results {
            let resultSwift = result as? ResultDataSwift
            self.appendResultToNSMutableAttributedString(resultSwift!,
                                                         upperCaseState,
                                                         mainText!,
                                                         resultSwift?.state == ResultDataSwift.RESULT_ALL && comparisonState != nil,
                                                         comparisonState)
        }

        self.updateMainTextView(true)
    }

    private func getMultiFileComparisonState(from results: [Any]) -> MultiFileComparisonState? {
        let completedResults = results.compactMap { $0 as? ResultDataSwift }.filter {
            $0.state == ResultDataSwift.RESULT_ALL
        }

        guard completedResults.count >= 2 else {
            return nil
        }

        func matchedValues(for values: [String]) -> Set<String> {
            var counts: [String: Int] = [:]
            for value in values {
                let normalizedValue = value.lowercased()
                guard !normalizedValue.isEmpty else { continue }
                counts[normalizedValue, default: 0] += 1
            }
            return Set(counts.compactMap { $0.value >= 2 ? $0.key : nil })
        }

        return MultiFileComparisonState(
            md5MatchedValues: matchedValues(for: completedResults.map(\.strMD5)),
            sha256MatchedValues: matchedValues(for: completedResults.map(\.strSHA256))
        )
    }

    private func updateDockProgress(_ value: Int) {
        var dockProgress = (Double(value) / self.mainProgressIndicator.maxValue)
        if (dockProgress >= 1) {
            dockProgress = 0.99999 // 1 will disappear.
        }
        // NSLog("dockProgress=%.10f", dockProgress)
        DockProgress.progress = dockProgress
    }

    private func bringWindowToFront() {
        DispatchQueue.main.async(execute: {
            self.view.window?.deminiaturize(self)
            NSApp.activate(ignoringOtherApps: true)
        })
    }

    private func appendFileNameToNSMutableAttributedString(_ result: ResultDataSwift,
                                                           _ nsmutAttrString: NSMutableAttributedString) {
        var strAppend = MacSwiftUtils.GetStringFromRes("FILENAME_STRING")
        strAppend += " "
        strAppend += result.strPath
        strAppend += "\n"
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutAttrString, strAppend)
    }

    private func appendFileMetaToNSMutableAttributedString(_ result: ResultDataSwift,
                                                           _ nsmutAttrString: NSMutableAttributedString) {
        let strSizeByte = String(format: "%llu", result.ulSize)
        let strShortSize = MacSwiftUtils.ConvertSizeToShortSizeStr(result.ulSize)

        var strAppend = MacSwiftUtils.GetStringFromRes("FILESIZE_STRING")
        strAppend += " "
        strAppend += strSizeByte
        strAppend += " "
        strAppend += MacSwiftUtils.GetStringFromRes("BYTE_STRING")
        if strShortSize != "" {
            strAppend += " ("
            strAppend += strShortSize
            strAppend += ")"
        }
        strAppend += "\n"
        strAppend += MacSwiftUtils.GetStringFromRes("MODIFYTIME_STRING")
        strAppend += " "
        strAppend += result.strMDate
        strAppend += "\n"

        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutAttrString, strAppend)
    }

    private func appendFileHashToNSMutableAttributedString(_ result: ResultDataSwift,
                                                           _ uppercase: Bool,
                                                           _ nsmutAttrString: NSMutableAttributedString,
                                                           _ shouldHighlightComparison: Bool,
                                                           _ comparisonState: MultiFileComparisonState?)
    {
        let strFileMD5: String
        let strFileSHA256: String

        if uppercase {
            strFileMD5 = result.strMD5.uppercased()
            strFileSHA256 = result.strSHA256.uppercased()
        } else {
            strFileMD5 = result.strMD5.lowercased()
            strFileSHA256 = result.strSHA256.lowercased()
        }

        let nsmutStrHash = NSMutableAttributedString()

        nsmutStrHash.beginEditing()

        var oldLength:Int = 0

        // MD5
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutStrHash, "MD5: ")
        oldLength = nsmutStrHash.length
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutStrHash, strFileMD5)
        nsmutStrHash.addAttribute(.link,
                                  value: strFileMD5,
                                  range: NSRange(location: oldLength, length: strFileMD5.count))
        applyHashHighlightIfNeeded(nsmutStrHash,
                                   rangeStart: oldLength,
                                   hashValue: strFileMD5,
                                   algorithmName: "MD5",
                                   shouldHighlightComparison,
                                   comparisonState)

        // SHA256
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutStrHash, "\nSHA256: ")
        oldLength = nsmutStrHash.length
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutStrHash, strFileSHA256)
        nsmutStrHash.addAttribute(.link,
                                  value: strFileSHA256,
                                  range: NSRange(location: oldLength, length: strFileSHA256.count))
        applyHashHighlightIfNeeded(nsmutStrHash,
                                   rangeStart: oldLength,
                                   hashValue: strFileSHA256,
                                   algorithmName: "SHA256",
                                   shouldHighlightComparison,
                                   comparisonState)

        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutStrHash, "\n\n")

        nsmutStrHash.endEditing()

        nsmutAttrString.append(nsmutStrHash)
    }

    private func applyHashHighlightIfNeeded(_ text: NSMutableAttributedString,
                                            rangeStart: Int,
                                            hashValue: String,
                                            algorithmName: String,
                                            _ shouldHighlightComparison: Bool,
                                            _ comparisonState: MultiFileComparisonState?) {
        guard shouldHighlightComparison,
              let comparisonState,
              !hashValue.isEmpty else {
            return
        }

        let outcome = comparisonState.outcome(for: algorithmName, hashValue: hashValue)
        let range = NSRange(location: rangeStart, length: hashValue.count)
        text.addAttribute(.foregroundColor,
                          value: outcome.foregroundColor,
                          range: range)
        text.addAttribute(.backgroundColor,
                          value: outcome.backgroundColor,
                          range: range)
    }

    private func appendFileErrToNSMutableAttributedString(_ result: ResultDataSwift,
                                                          _ nsmutAttrString: NSMutableAttributedString) {
        let strAppend = result.strError + "\n\n"
        MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutAttrString, strAppend)
    }

    private func appendResultToNSMutableAttributedString(_ result: ResultDataSwift,
                                                         _ uppercase: Bool,
                                                         _ nsmutAttrString: NSMutableAttributedString,
                                                         _ shouldHighlightComparison: Bool,
                                                         _ comparisonState: MultiFileComparisonState?) {
        if result.state == ResultDataSwift.RESULT_NONE {
            return
        }

        if result.state == ResultDataSwift.RESULT_ALL ||
            result.state == ResultDataSwift.RESULT_META ||
            result.state == ResultDataSwift.RESULT_ERROR ||
            result.state == ResultDataSwift.RESULT_PATH {
            self.appendFileNameToNSMutableAttributedString(result, nsmutAttrString)
        }

        if result.state == ResultDataSwift.RESULT_ALL ||
            result.state == ResultDataSwift.RESULT_META {
            self.appendFileMetaToNSMutableAttributedString(result, nsmutAttrString)
        }

        if (result.state == ResultDataSwift.RESULT_ALL) {
            self.appendFileHashToNSMutableAttributedString(result,
                                                           uppercase,
                                                           nsmutAttrString,
                                                           shouldHighlightComparison,
                                                           comparisonState)
        }

        if (result.state == ResultDataSwift.RESULT_ERROR) {
            self.appendFileErrToNSMutableAttributedString(result, nsmutAttrString)
        }

        if result.state != ResultDataSwift.RESULT_ALL &&
            result.state != ResultDataSwift.RESULT_ERROR {
            let strAppend = "\n"
            MacSwiftUtils.AppendStringToNSMutableAttributedString(nsmutAttrString, strAppend)
        }
    }

    @objc func onPreparingCalc() {
        // Copy old string.
        self.nsAttrStrNoPreparing = NSMutableAttributedString(attributedString: self.mainText!)

        var strAppend = MacSwiftUtils.GetStringFromRes("MAINDLG_WAITING_START")
        strAppend += "\n"
        MacSwiftUtils.AppendStringToNSMutableAttributedString(self.mainText, strAppend)

        self.updateMainTextView()
    }

    @objc func onRemovePreparingCalc() {
        // Reset old string.
        self.mainText = NSMutableAttributedString(attributedString: self.nsAttrStrNoPreparing!)
    }

    @objc func onCalcStop() {
        self.calculateStopped()
    }

    @objc func onCalcFinish() {
        self.calculateFinished()
    }

    @objc func onShowFileName(_ result: ResultDataSwift) {
        inMainQueue += 1
        DispatchQueue.main.async(execute: { [result] in
            self.outMainQueue += 1
            self.appendFileNameToNSMutableAttributedString(result, self.mainText!)
            if self.canUpdateMainTextView() {
                self.updateMainTextView()
            }
        })
    }

    @objc func onShowFileMeta(_ result: ResultDataSwift) {
        inMainQueue += 1
        DispatchQueue.main.async(execute: { [result] in
            self.outMainQueue += 1
            self.appendFileMetaToNSMutableAttributedString(result, self.mainText!)
            if self.canUpdateMainTextView() {
                self.updateMainTextView()
            }
        })
    }

    @objc func onShowFileHash(_ result: ResultDataSwift, uppercase: Bool) {
        inMainQueue += 1
        DispatchQueue.main.async(execute: { [result] in
            self.outMainQueue += 1
            let completedResults = (self.hashBridge?.getResults() ?? []).compactMap { $0 as? ResultDataSwift }.filter {
                $0.state == ResultDataSwift.RESULT_ALL
            }
            if completedResults.count >= 2 {
                self.refreshResultText()
            } else {
                self.appendFileHashToNSMutableAttributedString(result, uppercase, self.mainText!, false, nil)
                if self.canUpdateMainTextView() {
                    self.updateMainTextView()
                }
            }
        })
    }

    @objc func onShowFileErr(_ result: ResultDataSwift) {
        inMainQueue += 1
        DispatchQueue.main.async(execute: { [result] in
            self.outMainQueue += 1
            self.appendFileErrToNSMutableAttributedString(result, self.mainText!)
            if self.canUpdateMainTextView() {
                self.updateMainTextView()
            }
        })
    }

    @objc func onUpdateProgWhole(_ value: Int) {
        let oldValue = Int(self.mainProgressIndicator.doubleValue)
        if value == oldValue {
            return
        }

        self.mainProgressIndicator.doubleValue = Double(value)
        self.updateDockProgress(value)
    }

    @IBAction func openButtonClicked(_ sender: NSButton) {
        if state == .CALC_ING {
            self.stopHashCalc(false)
        } else {
            self.openFiles()
        }
    }

    @IBAction func clearButtonClicked(_ sender: NSButton) {
        if state == .VERIFY {
        } else {
            self.setViewControllerState(.NONE)
            self.updateMainTextView()
        }
    }

    @IBAction func verifyButtonClicked(_ sender: NSButton) {
        tag = NSTextFinder.Action.showFindInterface.rawValue
        mainTextView.performTextFinderAction(self)
    }

    @IBAction func uppercaseButtonClicked(_ sender: NSButton) {
        refreshActionButtonStyles()
        if state == .CALC_FINISH {
            self.refreshResultText()
        }
    }

    func textView(_ aTextView: NSTextView,
                  clickedOnLink link: Any,
                  at charIndex: Int) -> Bool {
        if aTextView == mainTextView {
            selectedLink = link as! String

            let nsptMouseLoc = NSEvent.mouseLocation
            let nsrtMouseInView = view.window!.convertFromScreen(NSRect(x: nsptMouseLoc.x, y: nsptMouseLoc.y, width: 0, height: 0))
            let nsptMouseInView = nsrtMouseInView.origin

            var nsmenuItem: NSMenuItem? = nil
            let nsmenuHash = NSMenu(title: "HashMenu")
            nsmenuItem = nsmenuHash.insertItem(
                withTitle: MacSwiftUtils.GetStringFromRes("MAINDLG_HYPEREDIT_MENU_COPY"),
                action: #selector(self.menuCopyHash),
                keyEquivalent: "",
                at: 0)
            if (!MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
                nsmenuItem?.image = NSImage(systemSymbolName: "document.on.document", accessibilityDescription: nil)
            }
            nsmenuHash.insertItem(NSMenuItem.separator(), at: 1)
            nsmenuItem = nsmenuHash.insertItem(
                withTitle: MacSwiftUtils.GetStringFromRes("MAINDLG_HYPEREDIT_MENU_SERACHGOOGLE"),
                action: #selector(self.menuSearchGoogle),
                keyEquivalent: "",
                at: 2)
            if (!MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
                nsmenuItem?.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
            }
            nsmenuItem = nsmenuHash.insertItem(
                withTitle: MacSwiftUtils.GetStringFromRes("MAINDLG_HYPEREDIT_MENU_SERACHVIRUSTOTAL"),
                action: #selector(self.menuSearchVirusTotal),
                keyEquivalent: "",
                at: 3)
            if (!MacSwiftUtils.IsSystemEarlierThan(26, 0)) {
                nsmenuItem?.image = NSImage(systemSymbolName: "safari", accessibilityDescription: nil)
            }

            nsmenuHash.popUp(positioning: nil, at: nsptMouseInView, in: view)

            return true
        }

        return false
    }

    @objc func menuCopyHash() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(selectedLink, forType: .string)
    }

    @objc func menuSearchGoogle() {
        let nstrUrl = "https://www.google.com/search?q=\(selectedLink)&ie=utf-8&oe=utf-8"
        let url = URL(string: nstrUrl)!
        NSWorkspace.shared.open(url)
    }

    @objc func menuSearchVirusTotal() {
        let nstrUrl = "https://www.virustotal.com/gui/search/\(selectedLink)"
        let url = URL(string: nstrUrl)!
        NSWorkspace.shared.open(url)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let findTextField = obj.object as? NSTextField else { return }

        let findString = findTextField.stringValue
        // NSLog("findTextField.stringValue [%@]", findString)

        // First, trim
        var fixedFindString = findString.trimmingCharacters(in: .whitespacesAndNewlines)

        // Second, regex
        let pattern = "^(?:MD5|SHA-?256)[\\s:=]+(.+)$"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let nsFixedString = fixedFindString as NSString
            let range = NSRange(location: 0, length: nsFixedString.length)
            if let match = regex.firstMatch(in: fixedFindString, options: [], range: range),
               match.numberOfRanges >= 2 {
                let hashRange = match.range(at: 1)
                fixedFindString = nsFixedString.substring(with: hashRange)
            }
        }

        if (fixedFindString.isEmpty || fixedFindString == findString) {
            return // no change
        }
        findTextField.stringValue = fixedFindString
        // NSLog("findTextField.stringValue fixedFindString=[%@]", fixedFindString)
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) ||
            commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
            tag = NSTextFinder.Action.nextMatch.rawValue
            mainTextView.performTextFinderAction(self)
            return true
        }

        return false
    }
}
