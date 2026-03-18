//
//  TitlebarView.swift
//  fHash
//
//  Created by Sun Junwen on 2025/12/18.
//  Copyright © 2025 Sun Junwen. All rights reserved.
//

import Cocoa

@objc(TitlebarView) class TitlebarView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let gradient = NSGradient(colors: [
            NSColor.windowBackgroundColor.withAlphaComponent(0.82),
            NSColor.windowBackgroundColor.withAlphaComponent(0.32),
            NSColor.windowBackgroundColor.withAlphaComponent(0.0)
        ])
        gradient?.draw(in: bounds, angle: 270)
    }

}
