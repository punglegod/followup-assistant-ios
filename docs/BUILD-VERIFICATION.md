# 构建验证记录

首次云端运行：https://github.com/punglegod/followup-assistant-ios/actions/runs/38117697967

- GitHub macOS 构建机器完成 iPhone Release 编译。
- iPhone 模拟器执行 7 项 XCTest，0 失败。
- 测试覆盖 CSV 多行及引号、Windows 换行、错误输入拒绝、问答匹配排序、去重指纹、备份往返及错误备份拒绝。
- 已下载产物并验证 `Payload/FollowUp.app/Info.plist` 与应用可执行文件存在，CPU 为 ARM64，最低 iOS 16。
- 最终打包显式设置版本号为 0.1.0，构建号为 1。

未签名 IPA 需要用户签名后安装。自动化检查未覆盖真机通知权限、专注模式、锁屏展示、实际文件导入导出及销售使用流程。这些应在安装后验证。

## v0.2.0

构建：https://github.com/punglegod/followup-assistant-ios/actions/runs/38119229809

代码提交：`b6ed2d4380bc2b41ee207e87e6fe3488b7bc5c5e`。Xcode 26.3，iPhoneOS 26.2 SDK，最低 iOS 16。

- 设备 Release 编译成功；IPA 版本 0.2.0，构建号 2。
- 17 项核心测试全部通过：原有 7 项、回访排期与迁移 6 项、PDF 文字/OCR 4 项。
- 2 项界面测试全部通过：底部导航和透明度操作；新客户自动安排第 3/7/21 天。
- 本地查看了模拟器预览图，确认页面和浮动底栏显示正常。
- 尚未在 iOS 27 真机验证视觉差异，也未覆盖实际品牌 PDF 和通知送达的真机测试。

Swift 5 模式编译通过。PDF 识别进度回调中的弱引用捕获有 Swift 6 迁移警告；当前回调通过 MainActor 更新状态，未来切换 Swift 6 时需调整捕获方式。AppIntents 元数据跳过是未使用该框架的构建提示。


## v0.2.1

旧版复现：https://github.com/punglegod/followup-assistant-ios/actions/runs/38120187684

旧版客户页搜索框底边为 841 pt，底部导航按钮顶部为 772 pt；新增布局检查按预期失败，截图确认两个控件叠在底部。

修复后测试：https://github.com/punglegod/followup-assistant-ios/actions/runs/38120823963

代码提交：`53d31d17b14409ae2ca59340e51c4b7a5ec7a4bf`。19 项核心测试和 5 项界面测试全部通过。该运行在测试完成后的附加模拟器安装/截图步骤停滞，手动取消；不能将工作流整体状态称为成功。随后移除了这段附加操作，使用 XCTest 导出的截图。

新增验证覆盖：客户和词库搜索栏与底栏分离、输入后底栏仍可点击；文件选择/取消回调；异步读取本机 PDF 和损坏文件错误；文件选择回调后关闭选择窗口、预览并导入词库。界面测试在 Debug 构建中向系统文件选择器代理注入本机文字 PDF；未自动点击文件应用的真实列表或覆盖真机第三方网盘。


最终成功构建：https://github.com/punglegod/followup-assistant-ios/actions/runs/38121923171

代码提交：`9666cf1a45346590dccda20afe9aebf841cca274`。设备 Release 编译、19 项核心测试、5 项界面测试、IPA 和日志附件上传全部成功。Xcode 26.3、iPhoneOS 26.2 SDK，iPhone 17 Pro / iOS 26.2 模拟器。已查看客户页、词库页和文字 PDF 导入预览截图，确认搜索框移到标题下方、底栏分离、PDF 预览包含识别内容。

最终 IPA 版本 0.2.1、构建号 3，最低 iOS 16，ARM64，未签名。iOS 27 真机、用户实际 PDF 和第三方网盘文件选择仍需真机验证。
