import SwiftUI
import AppKit

struct HistoryGalleryView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @State private var searchText: String = ""
    @ObservedObject var langManager = LanguageManager.shared

    var onSelectImage: (NSImage) -> Void

    var filteredItems: [ShotItem] {
        historyManager.filtered(query: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("menu.history_search_placeholder".localized, text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
            .padding()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                    ForEach(filteredItems) { item in
                        if let img = item.image {
                            VStack {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 110)
                                    .cornerRadius(6)
                                    .shadow(radius: 2)

                                Text(item.date, style: .date)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onTapGesture {
                                onSelectImage(img)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 650, height: 480)
    }
}
