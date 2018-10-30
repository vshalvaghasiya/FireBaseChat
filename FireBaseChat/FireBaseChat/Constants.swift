//
//  Constants.swift
//  FireBaseChat
//
//  Created by vishal on 13/12/17.
//  Copyright © 2017 vishal. All rights reserved.
//

import Foundation
import FirebaseCore
import FirebaseDatabase

struct Constants
{
    struct refs
    {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("messages")
        static let userIsTypingRef = databaseRoot.child("typingIndicator")
    }
}
