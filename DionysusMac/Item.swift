//
//  Item.swift
//  DionysusMac
//
//  Created by Adam Mhal on 9/22/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
