# 构建验证记录

首次云端运行：https://github.com/punglegod/followup-assistant-ios/actions/runs/38117697967

- GitHub macOS 构建机器完成 iPhone Release 编译。
- iPhone 模拟器执行 7 项 XCTest，0 失败。
- 测试覆盖 CSV 多行及引号、Windows 换行、错误输入拒绝、问答匹配排序、去重指纹、备份往返及错误备份拒绝。
- 已下载产物并验证 `Payload/FollowUp.app/Info.plist` 与应用可执行文件存在，CPU 为 ARM64，最低 iOS 16。
- 最终打包显式设置版本号为 0.1.0，构建号为 1。

未签名 IPA 需要用户签名后安装。自动化检查未覆盖真机通知权限、专注模式、锁屏展示、实际文件导入导出及销售使用流程。这些应在安装后验证。
