import SwiftUI

struct VisibleRowPreferenceKey: PreferenceKey {
    static let defaultValue: Set<Int> = []

    static func reduce(value: inout Set<Int>, nextValue: () -> Set<Int>) {
        value.formUnion(nextValue())
    }
}
