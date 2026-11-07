# CHANGELOG

## 1.0.0 (2026-11-07)

首个可发布版本。

**能力层**
- `preset/` 提供可安装 bundle `@local/dsh-boss-preset`，预设 id `boss`，`order: 0`（列表最靠前）。
- persona 内嵌主控协议：十条硬约束、L0–L4 分级、S1–S9 主循环、盲验四查与证据等级 E1–E4、可逆性阶梯 R0–R4、提问纪律、交付前六问。
- 工具集：文件/搜索/任务/网页/subagent/workflow/提问/todo/present/skill/plan-mode/compaction；`tool-plugin-manager` 与 `tool-plugin-market` 禁用。

**方法层**
- 技能 `boss-playbook`：目标卡、强制三案打分表、承诺卡、派工单、盲验提示词模板、复盘表。

**人**
- 6 张角色卡：researcher / analyst / builder / writer / verifier / red-team。
- `experts-registry.yaml`：能力注册表与路由算法。

**工程**
- `scripts/verify.ps1`：发布前静态自检（路径、frontmatter、YAML 结构、行尾），`-Fix` 可自动修正硬编码技能路径。
- `.gitattributes` 强制 LF；`.gitignore` 排除 node_modules 与备份目录。

**已知脆弱点**
- `preset/cordis.patch.yml` 的技能路径是全仓唯一硬编码绝对路径（框架以进程 cwd 解析相对路径）。移动目录后需 `verify.ps1 -Fix`，重启即生效。

**说明**
- 首轮交付的 README 曾出现行号与章节数错误（107 误作 61、"18 节"应为 21 节），已修正；本章节只记录结果，不保留错误内容。
