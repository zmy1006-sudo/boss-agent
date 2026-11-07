# BOSS Agent —— 已安装的 DSH 预设

这个目录是 BOSS Agent 的完整落地物。它不是一个文档，而是一个**能直接在 DeepSeek Harness 里选用的 Agent 预设**。

## 怎么用（30 秒）

1. 在 DSH Web UI 新建一个会话。
2. 在预设选择器里选 **BOSS**（order 0，排在列表最前）。
3. 直接给目标，例如「把这个仓库的构建时间降下来」，不要给步骤。

### 自检（第一次用建议跑一次）

在新会话里发：

> 用老板模式回答：我要把 boss-agent 目录整理成一个可发布的仓库，你打算怎么开始？

合格反应（缺任意一条说明预设没生效或没跑对）：

- 先给任务分级（L2 或 L3），并说明为什么定这一级；
- 写目标卡，把"可发布"翻译成可判定标准（如：README 存在、无绝对路径、能 `git init` 后干净提交）；
- 给三个结构性不同的方案（最小可行 / 推荐 / 非显然），带决策矩阵分数；
- 明确说"派工前会先开独立验证者"，且点名用 `subagent` 而不是 `subagent_fork`；
- 不反问"你想先做什么"。

如果它直接开始列目录、或者反问你想要什么风格，说明预设没挂上（见下面「排障」）。

## 文件地图

| 文件 | 作用 |
|---|---|
| `preset/cordis.patch.yml` | 预设本体。`preset-boss` 条目注册 agent preset，`persona.prefix` 是完整主控协议（十条硬约束 / L0–L4 分级 / S1–S9 主循环 / 盲验 / 授权红线 / 提问纪律 / 自检） |
| `preset/package.json` | bundle 声明，`dsh.bundle.patch` 指向上面那行 |
| `preset/skills/boss-playbook/SKILL.md` | 执行手册技能。L2+ 任务开始前加载，给可直接抄的模板（目标卡、三案打分表、承诺卡、派工单、盲验提示词、复盘表） |
| `prompts/researcher.md` `analyst.md` `builder.md` `writer.md` | 专家角色卡。派工给 `subagent` 时，把对应角色卡全文粘进 prompt |
| `prompts/verifier.md` | 独立验证者角色卡（盲验用） |
| `prompts/red-team.md` | 红队角色卡（L3+ 方案预演用） |
| `BOSS-Agent-设计文档.md` | 设计与论证（994 行，21 节 = 0–16 章 + 附录 A–D），改预设前先看它 |
| `boss-agent-system-prompt.md` | 纯提示词版（不用预设时的替代品） |
| `experts-registry.yaml` | 能力注册表与路由算法 |

## 专家怎么叫起来

专家不是常驻的，每次派工由 BOSS 用 `subagent` 现开一个干净上下文。派工单里必须包含角色卡全文，否则子代理不知道自己是谁。最省事的说法：

> 以 builder 角色执行。角色卡见 `D:\deepseek Harness\boss-agent\prompts\builder.md`，先读它再动手。

## 排障

- **看不到 BOSS**：预设由 profile 层 bundle 提供。重启 DSH 应用后仍看不到，检查 `C:\Users\赵铭远\.dsh\profiles\desktop\package.json` 里是否有 `@local/dsh-boss-preset`。
- **选了 BOSS 但行为像标准模式**：说明 preset 挂载失败被回落到默认。在设置里把会话切到 BOSS 重新新建一次；仍失败则看应用日志里的 `preset-boss` 相关报错。
- **`boss-playbook` 技能加载不了**：确认 `D:\deepseek Harness\boss-agent\preset\skills\boss-playbook\SKILL.md` 存在且首行是 `---`。该目录通过 `skill-filesystem-boss` 单独挂载（`D:/deepseek Harness/boss-agent/preset/skills`）。
- **路径必须存在**：`customSkillDirs` 写的是绝对路径（`preset/cordis.patch.yml` 第 107 行，`- 'D:/deepseek Harness/boss-agent/preset/skills'`；上一行 106 是 `customSkillDirs:`）。移动 `boss-agent` 目录后必须同步改这一行并重新安装，否则 `boss-playbook` 技能会静默消失。

## 卸载 / 回滚

**改完 patch 必须"先卸再装"**：直接重装会返回 `already-installed`（已实测），链式安装不会重读 YAML。

```powershell
# 让 DSH 里的 agent 依次执行（推荐，两条命令都做）：
#   plugin_manager remove_bundle   target: @local/dsh-boss-preset
#   plugin_manager install_bundle  target: D:\deepseek Harness\boss-agent\preset
```

**纯命令行**（不经过 DSH）时，顺序不能错：

```powershell
# 1) 必须先删 profile 里的两项，否则 loader 启动时解析不到 bundle 会报错
#    C:\Users\赵铭远\.dsh\profiles\desktop\package.json
#      - dependencies["@local/dsh-boss-preset"]
#      - dsh.profile.bundles 里的 "@local/dsh-boss-preset"
# 2) 再移除链接
cd C:\Users\赵铭远\.dsh\profiles\desktop
pnpm remove @local/dsh-boss-preset
# 3) 重启 DSH
```

**只停用、保留文件**：只做上面第 1、2 步里的删除 + pnpm remove，`boss-agent` 目录留着，下次重新安装即可。

**彻底删除**：

```powershell
Remove-Item -Recurse -Force "D:\deepseek Harness\boss-agent\preset"
```

回滚后行为回到标准模式，其他会话不受影响。

## 已知限制（诚实清单）

- **不改模型**：预设只改提示词、技能和工具集，不换模型。当前走 profile 默认（`modlens-huagong / deepseek-flash`）。
- **不持久化记忆**：L3 的「持续进化」目前靠 `boss-playbook` 里的复盘表和 `experts-registry.yaml` 手工沉淀，没有自动写入的长期记忆库。P3 才做。
- **盲验成本**：每次 L2+ 交付会多一个 subagent 的开销。这是刻意的——报告里看不到"我验证过了"，就不算完成。
- **预设不锁定工具**：`tool-plugin-manager`、`tool-plugin-market` 已禁用，但文件系统工具是完整的，BOSS 仍能改自己的预设文件。
