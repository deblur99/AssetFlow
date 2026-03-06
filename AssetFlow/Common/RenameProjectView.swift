//
//  RenameProjectView.swift
//  AssetFlow
//
//  Created by 한현민 on 3/6/26.
//

import SwiftUI

struct RenameProjectView: View {
    @State private var newName: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(name: String, onSave: @escaping (String) -> Void) {
        self._newName = State(initialValue: name)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Enter new name to rename the project")
                .font(.headline.bold())
            
            TextField("Project Name", text: $newName)
                .onSubmit {
                    onSave(newName)  // 엔터 키를 누르면 TextField의 onSubmit 클로저가 실행됨
                }
            
            HStack {
                Spacer()
                
                Button(role: .confirm) {
                    onSave(newName)
                } label: {
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .cancel) {
                    // No action needed, just close the sheet
                } label: {
                    Text("Cancel")
                }
            }
        }
        .frame(width: 300, height: 70)
        .padding()
    }
}

#Preview {
    RenameProjectView(name: "New Project") { name in
        print("Project renamed to: \(name)")
    }
}
