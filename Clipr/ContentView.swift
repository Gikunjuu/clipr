//
//  ContentView.swift
//  Clipr
//
//  Created by Collins Gikunju on 26/06/2026.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: CliprDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

#Preview {
    ContentView(document: .constant(CliprDocument()))
}
