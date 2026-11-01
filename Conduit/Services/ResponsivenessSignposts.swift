//
//  ResponsivenessSignposts.swift
//  Conduit
//
//  Intervals around the moments users feel, for the os_signpost track of a
//  device trace in Instruments (#1533): a chat open from the tap to Hermes'
//  rows, with an event when its saved rows show; a profile switch; the live
//  Chats list landing; the saves and parses a tap used to wait on; and a V2
//  tab switch, with the refreshes it starts, the tab bodies it redraws and
//  AppState's publishes, so one trace shows what a switch costs.
//  Signposts cost next to nothing while no trace records them, and they
//  record in Release builds, which a profile should be taken from.
//

import Foundation
import os

enum ResponsivenessSignposts {
    static let signposter = OSSignposter(subsystem: "com.milim.relay", category: "Responsiveness")

    /// One "View body" event per evaluation of a tab's root or the shell,
    /// so a trace counts the redraws a switch causes, hidden tabs included.
    @inline(__always)
    static func noteBody(_ view: StaticString) {
        signposter.emitEvent("View body", "\(view.description, privacy: .public)")
    }
}

/// A V2 tab switch, from the change of tab to the main thread's next turn,
/// after the frame that shows the new tab has been committed. Animation
/// Hitches in the same trace says whether that frame, and those after it,
/// were late.
@MainActor
enum TabSwitchSignpost {
    private static var open: OSSignpostIntervalState?

    static func begin(from: String, to: String, programmatic: Bool) {
        let signposter = ResponsivenessSignposts.signposter
        if let open { signposter.endInterval("Tab switch", open, "superseded") }
        let source = programmatic ? "programmatic" : "tap"
        open = signposter.beginInterval(
            "Tab switch",
            id: signposter.makeSignpostID(),
            "\(from, privacy: .public) to \(to, privacy: .public) (\(source, privacy: .public))"
        )
    }

    static func endAfterCommit() {
        guard let state = open else { return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard let current = open, current === state else { return }
                open = nil
                ResponsivenessSignposts.signposter.endInterval("Tab switch", state)
            }
        }
    }
}
