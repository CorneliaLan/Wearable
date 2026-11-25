import SwiftUI

struct StatusView: View {
    let status: TestStatus

    var body: some View {
        switch status {
        case .notTested:
            Text("–").foregroundStyle(.secondary)
        case .loading:
            ProgressView()
        case .value(let text):
            Text(text).foregroundStyle(.green).multilineTextAlignment(.trailing)
        case .noData:
            Text("keine Daten").foregroundStyle(.orange)
        case .error(let text):
            Text(text).foregroundStyle(.red).font(.caption).multilineTextAlignment(.trailing)
        }
    }
}
