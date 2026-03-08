//
//  Item.swift
//  Coordinates Converter
//
//  Created by Mickaël Fonck on 08/03/2026.
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
