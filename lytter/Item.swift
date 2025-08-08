import SwiftUI
import SwiftData

@Model final class Item {
  var timestamp: Date = Date()

  init(timestamp: Date = Date()) {
    self.timestamp = timestamp
  }
}
