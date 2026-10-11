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
