# 回访小助手（iPhone）

v0.2.0：客户档案、咨询后第 3/7/21 天的多次回访、可修改的周期与独立时间、本地通知、统计、问答与话术、CSV/PDF 导入、扫描 PDF 本机 OCR、可调透明度的 Liquid Glass 底部栏和完整备份恢复。

## GitHub 云端编译

仓库包含 `.github/workflows/build-ios.yml`。推送应用或构建变更到 main 后自动启动，也可以在 Actions → Build iPhone IPA → Run workflow 手动启动。工作流在 macOS 上编译未签名设备 IPA，并运行 iPhone 模拟器核心和界面测试。

运行完成后，在该次运行页面的 Artifacts 中下载 `FollowUp-unsigned-ipa`，解压后获得 `FollowUp-unsigned.ipa`，再自行签名安装。产物保留 14 天，构建日志在 `build-logs`。无需在仓库配置签名证书。

## 在 Mac 上生成 IPA

要求：安装完整 Xcode 26 或以上，启动一次完成组件安装；安装 XcodeGen（`brew install xcodegen`）。iPhone 最低 iOS 16。

在项目根目录执行：

```bash
bash scripts/test-ios.sh
bash scripts/build-ipa.sh
```

测试需要 Xcode 已安装可用的 iPhone 模拟器。打包成功后文件为 `build/FollowUp-unsigned.ipa`。这是未签名的设备应用，交给你的签名工具添加证书与描述文件后安装。签名工具可能需要调整 Bundle ID。证书到期或重装应用可能影响使用，卸载前请导出备份。

也可以执行 `xcodegen generate`，用 Xcode 打开生成的 `FollowUp.xcodeproj`，选择团队后直接运行到真机。当前没有图标素材，使用默认图标占位；应用界面使用原生中文表单。

验证记录见 `docs/BUILD-VERIFICATION.md`。真机安装、通知和实际资料仍需签名安装后验证。

## 导入已有资料

在“设置 → 导出填写模板”获得 CSV；也可使用 `templates/问答话术模板.csv`。Excel 按列填好，另存为 CSV UTF-8，传到 iPhone 文件应用，再从软件的“导入 CSV 资料”选择。类型只允许“问答”或“话术”；问题和回答必填。

| 类型 | 问题 | 相似问法 | 回答 | 产品 | 标签 | 来源 |
| --- | --- | --- | --- | --- | --- | --- |
| 问答 | 客户常问的问题 | 其他问法，用分号隔开 | 经确认的回答 | 产品名或留空 | 自定义标签 | 资料名称和版本 |
| 话术 | 首次回访 | 新客户跟进 | 常用回访文字 | 产品名或留空 | 首次回访 | 自有话术 |

样例仅示范格式，不含具体产品或症状建议。Word、XLSX 可先整理为 CSV；也可以在“问答与话术”点击加号逐条录入。每条条目均可编辑或删除。导入相同类型、问题和产品的条目会跳过，修改已有答案请使用编辑功能。

PDF 可直接从“设置 → 导入 PDF 资料（含扫描件）”选择：在本机提取文字，没有足够文字的扫描页尝试中文/英文 OCR。支持最多 100 页、20 MB，密码保护的 PDF 请先解除密码。识别后显示预览，可勾选和逐条编辑问题、回答、产品、来源。明确的“问：/答：”“问题：/回答：”“Q:/A:”按问答拆分；普通资料按页保留原文，带文件名和页码。扫描件识别可能出错，请核对原文后导入。

## 日常使用

1. 客户页面点击加号，填称呼、联系方式、咨询产品及咨询日期，自动安排第 3、7、21 天回访。编辑页可新增、删除或修改每项时间。
2. 设置页面开启通知授权，或修改默认周期和提醒时刻。修改默认周期只影响新客户及手动重新安排的客户。首页查看今日与逾期任务。
3. 打开客户详情，查看历史；从详情进入词库搜索产品相关内容，复制答案或话术。
4. 在客户详情选择“记录并完成这项回访”，保存结果；其他任务保留。临时沟通用“记录临时回访”，也可额外安排一次跟进。
5. 定期导出完整 JSON 备份，保存到安全位置。恢复前先备份现有数据。

搜索是本地资料匹配，相似结果需要人工核对适用产品与来源；搜不到时不会生成答案。产品统计每位客户按填写的产品字段计一次，暂不拆分多个产品。通知权限、系统专注模式及通知设置会影响展示；应用安排最近 59 项未来提醒，每次打开或保存时补充，其余任务仍在列表中。逾期任务次日上午合并提醒，不是每天永久重复。

旧版客户、历史、词库与单次回访自动迁移。旧版客户不自动加入新的默认周期，可从客户编辑页确认“按默认周期重新安排”。支持恢复旧版 JSON 备份；新版备份包含所有任务和设置。

## 底部栏透明度

设置 → 底部栏外观 → 玻璃透明度。0% 更实，100% 更透，文字保持清晰。iOS 26+（包括 iOS 27）调用原生 Liquid Glass 接口，iOS 16–18 使用兼容毛玻璃。系统的“减少透明度”设置优先，减少动态效果时关闭选中栏动画。效果受系统版本、深浅色主题与辅助功能设置影响，未宣称已在 iOS 27 真机测试。

## 检查状态

源码包含核心和界面测试，覆盖 CSV、搜索、备份、日期周期、旧数据迁移、单项回访完成、文字 PDF 与扫描 OCR、底栏导航和新建客户排期。`scripts/test-ios.sh` 在 Mac 执行并保存结果和预览图。真机还需确认导入、复制、备份恢复、通知授权与杀进程后的通知。

Windows 静态检查命令：

```powershell
python -m pip install tree-sitter tree-sitter-swift pyyaml
python scripts/check-source.py
```

文件导入采用 Apple 的安全作用域访问方式：[Apple fileImporter 文档](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aoncompletion%3A%29)。

玻璃底栏参照 [Apple Liquid Glass 文档](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)。PDF 使用 [PDFKit](https://developer.apple.com/documentation/pdfkit/pdfdocument/string)，扫描页使用 [Vision 文字识别](https://developer.apple.com/documentation/vision/recognizing-text-in-images)。
