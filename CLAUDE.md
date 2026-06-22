# 项目约定

## 提交规范
- 不允许自动push代码
- 提交 commit 时不要在 author、Co-Authored-By 或 commit message 中包含 Claude / Anthropic 标识。
- 仅保留用户自己的 git 身份归属。
- 每次提交前检查本次改动是否需要更新 README：若改动涉及 README 中已记载的内容（功能、安装/运行步骤、项目结构、用法等），或新增/移除了 README 应当记录的特性，先把 README 一并更新再提交；若与 README 无关则跳过。无法判断时向用户说明并询问。

## 语言
- 文档（`docs/`、README、spec、plan、ADR）一律使用中文。
- 代码注释（`///` `//` `/* */`）一律使用中文。
- 标识符、API 名称、英文错误术语等不需要翻译。
