import SwiftUI

struct FilterBarView: View {
    @Binding var filter: MediaFilter
    let onFilterChanged: (MediaFilter) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Picker("Filter", selection: $filter) {
                ForEach(MediaFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue)
                        .tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 260)
            .onChange(of: filter) { _, newValue in
                onFilterChanged(newValue)
            }

            Spacer()

            Text(keyboardHint)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
                .padding(.trailing, 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var keyboardHint: String {
        "Space: Select  |  Tab: Switch Column  |  Enter: Compare"
    }
}
