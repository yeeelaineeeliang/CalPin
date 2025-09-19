//
//  CalPinApp.swift
//  CalPin
//
//  Created by 李歌 on 9/23/23.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

@main
struct MyApp: App {
//Handles Google Sign-In URL scheme configuration
//Sets up the root ContentView

  var body: some Scene {
    WindowGroup {
//      MapView()
      ContentView()
        // ...
        .onOpenURL { url in
          GIDSignIn.sharedInstance.handle(url)
        }
//        .onAppear {
//            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
//              // Check if `user` exists; otherwise, do something with `error`
//            }
//          }
    }
  }
}

struct Previews_CalPinApp_Previews: PreviewProvider {
    static var previews: some View {
        /*@START_MENU_TOKEN@*/Text("Hello, World!")/*@END_MENU_TOKEN@*/
    }
}
