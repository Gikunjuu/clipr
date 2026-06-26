//
//  CliprApp.swift
//  Clipr
//
//  Created by Collins Gikunju on 26/06/2026.
//

import SwiftUI

@main
struct CliprApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: CliprDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
