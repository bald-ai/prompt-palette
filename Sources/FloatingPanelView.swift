import SwiftUI

struct FloatingPanelView: View {
    let items: [PromptItem]
    let title: String
    let highlightedIndex: Int?
    let isNested: Bool
    let isSearching: Bool
    let searchQuery: String
    let footerText: String
    let transitionDirection: PickerTransitionDirection
    let onBack: () -> Void
    let onActivateSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            searchBar
            content
            divider
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .preferredColorScheme(.dark)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(height: 1)
    }

    /// Always-visible search field. Click (or press Tab) to activate filtering.
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(isSearching ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))

            ZStack(alignment: .leading) {
                if searchQuery.isEmpty {
                    Text(isSearching ? "Type to filter…" : "Search prompts…")
                        .foregroundStyle(Color.white.opacity(0.32))
                }
                if isSearching {
                    HStack(spacing: 1) {
                        Text(searchQuery)
                            .foregroundStyle(.white)
                        Rectangle()
                            .fill(Theme.accent)
                            .frame(width: 2, height: 17)
                    }
                }
            }
            .font(.system(size: 15))

            Spacer()

            if isSearching == false {
                Text("⇥")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(isSearching ? 0.07 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSearching ? Theme.accent.opacity(0.6) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { onActivateSearch() }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if isNested {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.titleGradient)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Text(isSearching ? "No matches" : "This folder is empty")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            VStack(spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    PromptRow(
                        index: index,
                        item: item,
                        isHighlighted: index == highlightedIndex,
                        isSearching: isSearching
                    )
                }
            }
            .padding(8)
        }
    }

    private var footer: some View {
        Text(footerText)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
    }
}

private struct PromptRow: View {
    let index: Int
    let item: PromptItem
    let isHighlighted: Bool
    let isSearching: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isSearching {
                Text(isHighlighted ? "›" : "")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
            } else {
                keyChip
            }

            Text(item.isFolder ? "📁" : "✦")
                .font(.system(size: 14))
                .frame(width: 20)
                .opacity(0.85)

            Text(item.title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            Text(hintText)
                .font(.system(size: 12))
                .foregroundStyle(isHighlighted ? Color.white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHighlighted ? AnyShapeStyle(Theme.rowHighlightGradient) : AnyShapeStyle(Color.clear))
        )
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

    private var keyChip: some View {
        Text(keyLabel(for: index))
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(isHighlighted ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(chipBaseGradient))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.white.opacity(isHighlighted ? 0.4 : 0.12), lineWidth: 1)
            )
            .shadow(color: isHighlighted ? Theme.accent.opacity(0.55) : .black.opacity(0.4),
                    radius: isHighlighted ? 6 : 2, x: 0, y: 2)
    }

    private var chipBaseGradient: LinearGradient {
        LinearGradient(
            colors: [Color(white: 0.24), Color(white: 0.16)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var hintText: String {
        if item.isFolder {
            let count = item.children?.count ?? 0
            return "\(count) items ›"
        }
        return isHighlighted ? "↩ run" : "↩"
    }

    private func keyLabel(for index: Int) -> String {
        switch index {
        case 0...4: return "\(index + 1)"
        case 5: return "Q"
        case 6: return "W"
        case 7: return "E"
        case 8: return "R"
        default: return "?"
        }
    }
}
