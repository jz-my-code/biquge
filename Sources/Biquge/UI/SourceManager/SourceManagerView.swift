import SwiftUI

// MARK: - 书源管理页

/// 展示所有书源，允许启用/停用、添加、删除
struct SourceManagerView: View {
    @EnvironmentObject private var store: SourceStore
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.sources) { source in
                    SourceRow(source: source) {
                        store.setEnabled(sourceId: source.id, enabled: !source.enabled)
                    }
                }
                .onDelete { idx in
                    idx.forEach { store.remove(sourceId: store.sources[$0].id) }
                }
            }
            .navigationTitle("书源管理")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
            .alert("导入书源", isPresented: $showImporter) {
                TextField("粘贴书源 JSON", text: .constant(""), axis: .vertical)
            }
            .sheet(isPresented: $showImporter) {
                ImportSourceView { json in
                    do {
                        guard let data = json.data(using: .utf8) else {
                            throw ImportError.invalidEncoding
                        }
                        let decoder = JSONDecoder()
                        if let source = try? decoder.decode(BookSource.self, from: data) {
                            store.add(source: source)
                            showImporter = false
                            return
                        }
                        // 可能是数组
                        if let arr = try? decoder.decode([BookSource].self, from: data) {
                            arr.forEach { store.add(source: $0) }
                            showImporter = false
                            return
                        }
                        throw ImportError.parseFailed
                    } catch {
                        importError = "解析失败：\(error.localizedDescription)"
                    }
                }
            }
            .alert("提示", isPresented: Binding<Bool>(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("确定") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    enum ImportError: Error { case invalidEncoding, parseFailed }
}

// MARK: - 书源行

struct SourceRow: View {
    let source: BookSource
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.bookSourceName)
                    .font(.body)
                    .lineLimit(1)
                Text(source.bookSourceUrl.cleanBaseUrl)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { source.enabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(.orange)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 导入书源页

struct ImportSourceView: View {
    @Environment(\.dismiss) private var dismiss
    let onImport: (String) -> Void

    @State private var jsonText = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $jsonText)
                    .font(.system(.body, design: .monospaced))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    }
                    .overlay(alignment: .topLeading) {
                        if jsonText.isEmpty {
                            Text("粘贴书源 JSON…")
                                .foregroundStyle(.tertiary)
                                .padding(8)
                        }
                    }

                Button("导入") {
                    guard !jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onImport(jsonText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(jsonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("导入书源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}