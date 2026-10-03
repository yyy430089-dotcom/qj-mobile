import SwiftUI

struct WelcomeView: View {
    @State private var sample = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "character.cursor.ibeam").font(.system(size: 40)).foregroundStyle(.blue)
                        Text("好好输入，顺便认识一个词。")
                            .font(.title2.bold())
                        Text("简词键盘 · 基于青简的个人 iPhone 移植版")
                            .foregroundStyle(.secondary)
                    }.padding(.vertical, 10)
                }
                Section("启用键盘") {
                    Text("1. 打开 iPhone 设置 → 通用 → 键盘 → 键盘。")
                    Text("2. 选择“添加新键盘”，添加“简词键盘”。")
                    Text("3. 在输入框中，按住地球键选择简词键盘。")
                    Text("无需开启“允许完全访问”。拼音转换和英文译词都在手机上完成。")
                        .foregroundStyle(.secondary)
                }
                Section("试着输入") {
                    TextField("切换简词，输入 kaifa 或 nihao", text: $sample, axis: .vertical)
                        .lineLimit(3...5).autocorrectionDisabled()
                        .accessibilityIdentifier("keyboardTestField")
                    Text("英文只作辅助提示，点候选提交中文。空格选首个候选；取消清空未上屏拼音。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("安装与续签") {
                    Text("免费侧载通常每 7 天需要续签。请在到期前通过 Windows 上的 AltServer 与手机上的 AltStore 刷新此应用；安装和更新时保留键盘扩展。")
                    Link("AltStore Windows 安装说明", destination: URL(string: "https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows")!)
                }
                Section("关于与开源致谢") {
                    Text("版本 0.1.0 · 个人测试版")
                    Text("输入引擎源于青简 v0.1.4；本项目代码采用 GPL-3.0-or-later。简词是独立移植项目。")
                    Text("基础词库来源、数据许可与署名见随包 Licenses。英文释义由上游用模型生成，可能存在错译。")
                    Link("青简上游源码", destination: URL(string: "https://github.com/qingjian-team/qingjian/tree/v0.1.4")!)
                    NavigationLink("许可证与数据来源") { LicenseView() }
                }
            }
            .navigationTitle("简词键盘")
        }
    }
}
