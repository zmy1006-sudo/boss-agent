# BOSS Agent

一个装在 DeepSeek Harness 里的 **Agent 预设**：你只提目标，它负责判断问题、选路、派人、验收、交付。

不是一个提示词文件，而是三层结构：预设（能力）+ 技能（方法）+ 角色卡（人）。

## 它解决什么

普通的 Agent 你问它做什么，它做；你说个目标，它反问你"你想怎么做"。

BOSS 的差别是四条硬约束：**先判断这是不是真问题**（目标卡）、**不许只做第一个想到的方案**（强制三案）、**交付前必须由别的上下文验一遍**（盲验）、**不可逆的动作先要授权**（可逆性阶梯）。这些是写进 persona 的硬规则，不是"建议"。

## 安装

### 0. 前置

- 已安装 DeepSeek Harness，能打开 Web UI
- 版本要求：**桌面版 0.2.1-rc.5 及以上**（该版本的运行时包含补丁引用的全部插件包）
- CLI 版未验证：`dsh` 0.1.0-rc.7 缺少 `dsh-agent-preset`、`dsh-plugin-manager`、`dsh-plugin-market`、`dsh-tool-present`、`dsh-tool-schedule`、`dsh-workflow-ptc` 等包，用它安装会成功但 BOSS 不会出现在预设列表里。用 CLI 的话请先确认这些包存在。
- Node.js / pnpm 可用（`plugin_manager` 依赖它）
- 仓库放在本机任意目录，**路径可以带空格**（脚本已经按带空格的情况处理）

### 1. 安装预设

在 DSH 里让 agent 执行：

```
plugin_manager  install_bundle  target: <仓库绝对路径>\preset
```

或者用命令行：

```powershell
cd $env:USERPROFILE\.dsh\profiles\<你的 profile 名>
pnpm add "link:<仓库绝对路径>\preset"
```

装完重启 DSH。新建会话时，预设列表里会出现 **BOSS**，位置最靠前。

### 2. 验证安装

```powershell
# 静态检查：路径、frontmatter、YAML 结构、行尾
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1

# 目录被移动过、提示路径不对时，自动修正
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1 -Fix
```

**刚 clone 下来的第一次运行，出现 2 个 FAIL 是预期的**：技能路径还指向原作者的目录，同一行会同时触发"路径不符"和"残留绝对路径"两项。跑一次 `verify.ps1 -Fix` 就会改对，再跑一次应为全 PASS。

`PASS` 只代表静态结构没问题，**不代表装得上**。装完必须跑下面这次会话自检。

### 3. 换到 BOSS 跑一次

新建会话，预设选 **BOSS**，发：

> 用老板模式回答：我要把这个仓库整理成可发布的版本，你打算怎么开始？

合格反应（缺任意一条说明预设没挂上或没生效）：

1. 先给分级（L2 或 L3），并说明为什么定这一级；
2. 写目标卡，把"可发布"翻译成可判定标准；
3. 给三个结构性不同的方案，带决策矩阵分数；
4. 明确说派工前会开独立验证者，且点名用 `subagent` 而不是 `subagent_fork`；
5. 不反问"你想先做什么"。

## 目录结构

```
README.md                      本文件
BOSS-Agent-设计文档.md          完整设计与论证（21 节）
boss-agent-system-prompt.md    纯提示词版，不用预设时粘贴它
experts-registry.yaml          专家能力注册表 + 路由算法
prompts/                       6 张专家角色卡（派工时拼进派工单）
preset/                        可安装的 bundle
  package.json
  cordis.patch.yml             预设本体：persona 协议 + 工具集
  skills/boss-playbook/SKILL.md 方法层：目标卡、三案表、派工单、盲验模板
scripts/verify.ps1             发布前静态自检
```

## 专家怎么叫起来

专家不常驻。每次派工由 BOSS 用 `subagent` 现开一个干净上下文，派工单里必须包含角色卡全文，否则子代理不知道自己是谁。最省事的说法：

> 以 builder 角色执行。先读 `prompts/builder.md`，再动手。

## 修改后怎么生效

预设是以**目录链接**（pnpm `link:` → Junction）装进 profile 的，`cordis.patch.yml` 每次启动都从仓库里现读。所以：

- **改了 `cordis.patch.yml` / 技能 / persona 文本**：重启 DSH 即可，不必重装。
- **改了 `preset/package.json` 的包名或 `dsh.bundle` 声明**、或换了仓库位置：需要重装。直接 `install_bundle` 会返回 `already-installed`，先卸再装：

```
plugin_manager  remove_bundle   target: @local/dsh-boss-preset
plugin_manager  install_bundle  target: <仓库绝对路径>\preset
```

## 排障

- **看不到 BOSS**：预设由 profile 层 bundle 提供。重启后仍看不到，检查 `%USERPROFILE%\.dsh\profiles\<profile>\package.json` 的 `dsh.profile.bundles` 里有没有 `@local/dsh-boss-preset`。
- **选了 BOSS 但行为像标准模式**：说明预设挂载失败被回落到默认。重新新建一次会话；仍失败则看应用日志里 `preset-boss` 的报错。
- **`boss-playbook` 技能加载不了**：确认 `preset/skills/boss-playbook/SKILL.md` 存在且首行是 `---`。
- **技能路径是硬编码的**：`preset/cordis.patch.yml` 里的 `customSkillDirs` 是全仓库唯一一处必须写绝对路径的地方（框架的 `resolve()` 以进程 cwd 为基准，相对路径会静默错）。移动目录后跑一次 `verify.ps1 -Fix` 再重启，否则技能会无声消失。
- **装完就别挪那个目录**：装好后移动或删除仓库，会让 profile 里的链接悬空；loader 启动时解析 `dsh.profile.bundles` 失败，DSH 可能起不来。真挪了，从 `%USERPROFILE%\.dsh\profiles\<profile>\package.json` 的 `dependencies` 和 `dsh.profile.bundles` 里删掉两项即可恢复。

## 卸载 / 回滚

```
plugin_manager  remove_bundle  target: @local/dsh-boss-preset
```

纯命令行时，`dependencies` 和 `dsh.profile.bundles` 里的两项**最终都必须删掉**——只要下次启动前还留着一项，loader 就会因为解析不到 bundle 而报错。先删两项再 `pnpm remove` 最省事（经 `plugin_manager` 卸载会自动处理，无需手工）。

回滚后行为回到标准模式，其他会话不受影响。

## 已知限制（诚实清单）

- **不改模型**：预设只改提示词、技能和工具集，不换模型，走 profile 的默认模型。
- **不持久化记忆**：L3 的"持续进化"目前靠 `boss-playbook` 的复盘表和 `experts-registry.yaml` 手工沉淀，没有自动写入的长期记忆库。
- **盲验有成本**：L2+ 每次交付多一个 subagent 的开销。这是刻意的——报告里看不到验证结论，就不算完成。
- **不锁工具**：`tool-plugin-manager`、`tool-plugin-market` 已禁用，但文件系统工具完整，BOSS 仍能改自己的预设文件。

## 许可

MIT，见 [LICENSE](LICENSE)。
