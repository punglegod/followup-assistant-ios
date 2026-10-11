# 回访小助手（iPhone）

已实现第一版源码：客户档案、回访记录和排期、本地通知、统计、问答与话术搜索、手动编辑、CSV 批量导入与预览、完整备份恢复。

## GitHub 云端编译

仓库包含 `.github/workflows/build-ios.yml`。推送到 main 后自动启动，也可以在 Actions → Build iPhone IPA → Run workflow 手动启动。工作流在 macOS 上编译未签名设备 IPA，并运行 iPhone 模拟器核心测试。

运行完成后，在该次运行页面的 Artifacts 中下载 `FollowUp-unsigned-ipa`，解压后获得 `FollowUp-unsigned.ipa`，再自行签名安装。产物保留 14 天，构建日志在 `build-logs`。无需在仓库配置签名证书。

## 在 Mac 上生成 IPA

要求：安装完整 Xcode，启动一次完成组件安装；安装 XcodeGen（`brew install xcodegen`）。iPhone 最低 iOS 16。

在项目根目录执行：

```bash
bash scripts/test-ios.sh
bash scripts/build-ipa.sh
```

测试需要 Xcode 已安装可用的 iPhone 模拟器。打包成功后文件为 `build/FollowUp-unsigned.ipa`。这是未签名的设备应用，交给你的签名工具添加证书与描述文件后安装。签名工具可能需要调整 Bundle ID。证书到期或重装应用可能影响使用，卸载前请导出备份。

也可以执行 `xcodegen generate`，用 Xcode 打开生成的 `FollowUp.xcodeproj`，选择团队后直接运行到真机。当前没有图标素材，使用默认图标占位；应用界面使用原生中文表单。

**当前交付是源码，尚未在 Xcode 编译或真机验证，也没有生成 IPA。Windows 环境没有 iOS SDK。**

## 导入已有资料

在“设置 → 导出填写模板”获得 CSV；也可使用 `templates/问答话术模板.csv`。Excel 按列填好，另存为 CSV UTF-8，传到 iPhone 文件应用，再从软件的“导入 CSV 资料”选择。类型只允许“问答”或“话术”；问题和回答必填。

| 类型 | 问题 | 相似问法 | 回答 | 产品 | 标签 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| 问答 | 客户常问的问题 | 其他问法，用分号隔开 | 经确认的回答 | 产品名或留空 | 自定义标签 | 资料名称和版本 |
| 话术 | 首次回访 | 新客户跟进 | 常用回访文字 | 产品名或留空 | 首次回访 | 自有话术 |

样例仅示范格式，不含具体产品或症状建议。Word、PDF、XLSX 不直接解析，可把内容整理到模板中；也可以在“问答与话术”点击加号逐条录入。每条条目均可编辑或删除。导入相同类型、问题和产品的条目会跳过，修改已有答案请使用编辑功能。

## 日常使用

1. 客户页面点击加号，填称呼、联系方式、咨询产品及备注，开启回访安排。
2. 设置页面开启通知授权。首页查看今日与逾期客户。
3. 打开客户详情，查看历史；从详情进入词库搜索产品相关内容，复制答案或话术。
4. 沟通结束后点击“记录本次回访”，保存结果并安排下次回访。
5. 定期导出完整 JSON 备份，保存到安全位置。恢复前先备份现有数据。

搜索是本地资料匹配，相似结果需要人工核对适用产品与来源；搜不到时不会生成答案。产品统计每位客户按填写的产品字段计一次，暂不拆分多个产品。通知权限、系统专注模式及通知设置会影响展示；第一版安排最近 59 项未来提醒，每次打开或保存时补充，其余任务仍在列表中。逾期任务次日上午合并提醒，不是每天永久重复。

## 检查状态

源码包含 XCTest 核心测试，覆盖 CSV 格式、排序、备份等。`scripts/test-ios.sh` 在 Mac 执行。真机还需确认导入、复制、备份恢复、通知授权与杀进程后的通知。当前 Windows 侧只能执行静态语法检查，不能替代 Xcode 编译和实机测试。

Windows 静态检查命令：

```powershell
python -m pip install tree-sitter tree-sitter-swift pyyaml
python scripts/check-source.py
```

文件导入采用 Apple 的安全作用域访问方式：[Apple fileImporter 文档](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29)。
