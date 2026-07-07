import AppKit
import SwiftUI

struct ManagementView: View {
    @ObservedObject var store: PromptStore
    @ObservedObject var viewModel: ManagementViewModel
    var usageStatsStore: UsageStatsStore
    var onExit: () -> Void = {}

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
            editor
                .frame(minWidth: 400)
        }
        .frame(minWidth: 720, minHeight: 480)
        .preferredColorScheme(.dark)
        .onAppear { viewModel.ensureInitialSelection() }
        .onReceive(store.$prompts) { _ in viewModel.handlePromptsChanged() }
        .alert("Discard unsaved changes?", isPresented: $viewModel.showingDiscardAlert) {
            Button("Keep Editing", role: .cancel) { viewModel.showingDiscardAlert = false }
            Button("Discard", role: .destructive) { viewModel.confirmDiscardChanges() }
        } message: {
            Text("Your current edits will be lost.")
        }
        .alert("Delete Folder?", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { viewModel.showingDeleteConfirmation = false }
            Button("Delete", role: .destructive) { viewModel.confirmDeleteSelectedItem() }
        } message: {
            Text(viewModel.deleteConfirmationMessage)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Prompts")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                toolbarButton(systemName: "plus", help: "New Prompt") {
                    viewModel.requestCreateNewPrompt()
                }
                .disabled(viewModel.canCreateInTargetParent == false)

                toolbarButton(systemName: "folder.badge.plus", help: "New Folder") {
                    viewModel.requestCreateNewFolder()
                }
                .disabled(viewModel.canCreateInTargetParent == false)

                toolbarButton(systemName: "trash", help: "Delete") {
                    viewModel.requestDeleteSelectedItem()
                }
                .disabled(viewModel.canDelete == false)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 8)

            if viewModel.visibleRows.isEmpty {
                VStack(spacing: 8) {
                    Spacer().frame(height: 60)
                    Text("No prompts yet")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Create a prompt or folder to get started.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ManagementOutlineView(viewModel: viewModel)
            }

            Rectangle().fill(Color.black.opacity(0.6)).frame(height: 1)

            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.green)
                    .frame(width: 6, height: 6)
                Text("\(usageStatsStore.loadTotalUsedAllTime()) prompts used all time")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Theme.sidebarBackground)
    }

    private func toolbarButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .frame(width: 27, height: 27)
        }
        .buttonStyle(ToolbarIconButtonStyle())
        .help(help)
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.hasSelection {
                editorContent
            } else {
                VStack {
                    Spacer()
                    Text("Select a prompt or folder from the sidebar, or create a new one.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.editorBackground)
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 15) {
            crumb

            Text(viewModel.draftTitle.isEmpty ? "Untitled" : viewModel.draftTitle)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(viewModel.draftTitle.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                .lineLimit(1)

            pills

            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("Title")
                TextField("Enter title", text: $viewModel.draftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9).fill(Theme.fieldBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1)
                    )
                    .onSubmit { viewModel.saveChanges() }
            }

            if viewModel.isEditingPrompt {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("Content")
                    TextEditor(text: $viewModel.draftContent)
                        .font(.system(size: 13).monospaced())
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10).fill(Theme.contentBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1)
                        )
                }
            } else {
                Text("Folders organize prompts and subfolders. They don't have content.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Spacer()
            }

            if let message = viewModel.validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                Button("Cancel") { viewModel.cancelEditing() }
                    .buttonStyle(GhostButtonStyle())
                Button("Save") { viewModel.saveChanges() }
                    .buttonStyle(AccentButtonStyle())
                    .keyboardShortcut(.return, modifiers: .command)
                Spacer()
                Button("Exit") { onExit() }
                    .buttonStyle(GhostButtonStyle())
                    .keyboardShortcut("q", modifiers: .command)
            }
        }
        .padding(26)
    }

    private var crumb: some View {
        HStack(spacing: 5) {
            if let parent = viewModel.editorParentTitle {
                Text(parent)
                Text("›")
            }
            Text(viewModel.editorKindLabel)
        }
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
    }

    private var pills: some View {
        HStack(spacing: 8) {
            pill(viewModel.editorKindLabel)
            if let usage = viewModel.promptUsageText {
                pill(usage)
            } else if let count = viewModel.folderChildCount {
                pill("\(count) item\(count == 1 ? "" : "s")")
            }
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .tracking(0.4)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Button Styles

private struct ToolbarIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.13 : 0.06))
            )
            .opacity(isEnabled ? 1 : 0.3)
    }
}

private struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(configuration.isPressed ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.10 : 0.0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1)
            )
    }
}

private struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9).fill(Theme.accentGradient)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
