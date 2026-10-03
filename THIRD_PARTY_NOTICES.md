# 开源与数据来源

QJMobile / 简词键盘是独立的个人移植项目，不是青简官方 iOS 产品，不使用青简 logo。

## 输入引擎

四个 `vendor/qingjian-*` crate 来自 qingjian-team/qingjian 的 `v0.1.4`，固定提交
`f7abaefcb1a3aeaca5c01692941a64a7b1f43eb5`，保持原代码及注释。原项目与本移植代码采用 GPL-3.0-or-later，原文见 LICENSE。

上游：https://github.com/qingjian-team/qingjian/tree/v0.1.4

## 基础词库

DataSource/dict.tsv 原样来自上游 assets/lexicon/dict.tsv。规范汉字表、现代汉语常用词表的转录仓库未附单独许可证；上游的数据来源说明保留在 Licenses/LEXICON-README.md、LEXICON-SOURCES.md 与 UPSTREAM-DATA-SOURCES.md。本项目不为这些来源补造授权。

THUOCL：Copyright (c) 2018 THUNLP，MIT，全文见 Licenses/THUOCL-MIT.txt。

Unihan 读音：Unicode License v3，全文见 Licenses/UNICODE-LICENSE.txt。

词频由上游统计生成，来源涉及中文维基（CC BY-SA 4.0）与 LCCC（MIT），详见随附的上游来源清单。

## 英文译词

DataSource/glossary-en.tsv 是上游同名表中、基础词库包含词形的子集；筛选过程不改译词。上游采用 GPL-3.0-or-later 发布，由模型离线生成，不含在线词典抓取内容。译词可能不准确。完整来源见 Licenses/GLOSSARY-README.md。

## 构建依赖

Rust 第三方依赖由 Cargo.lock 固定；构建脚本生成 Licenses/RUST-DEPENDENCIES.json，并随应用打包依赖名称、版本、许可证及仓库链接。
XcodeGen 用于生成项目，采用 MIT 许可，不嵌入应用运行时。

源码与源数据的校验值见 UPSTREAM.json。公开仓库不含 Apple 账号、凭据、本机用户词库、个人输入日志或个人设置。
