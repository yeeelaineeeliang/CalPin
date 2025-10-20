//
//  CustomPinView.swift
//  CalPin
//

import Foundation
import SwiftUI

struct CustomPinView: View {
    let title: String

    var body: some View {
        VStack {
            Image(systemName: "mappin.circle.fill") // Use your custom image here
                .resizable()
                .foregroundColor(.red)
                .frame(width: 30, height: 30)
            Text(title)
                .font(.caption)
        }
    }
}
