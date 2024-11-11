//
//  Item.swift
//  BIGHDOOKIE
//
//  Created by Bobby Smith on 10/31/24.
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
