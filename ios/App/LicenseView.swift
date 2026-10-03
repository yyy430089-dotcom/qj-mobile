import SwiftUI

struct LicenseView: View {
    private let files = ["LICENSE", "THIRD_PARTY_NOTICES.md", "THUOCL-MIT.txt", "UNICODE-LICENSE.txt", "LEXICON-README.md", "LEXICON-SOURCES.md", "GLOSSARY-README.md", "UPSTREAM-DATA-SOURCES.md", "RUST-DEPENDENCIES.json"]
    var body: some View {
        List(files, id: \.self) { name in
            NavigationLink(name) {
                ScrollView {
                    Text(contents(name)).font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding()
                }.navigationTitle(name).navigationBarTitleDisplayMode(.inline)
            }
        }.navigationTitle("开源许可与来源")
    }
    private func contents(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Licenses"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "未找到许可文件，请查看完整源码包。" }
        return text
    }
}
