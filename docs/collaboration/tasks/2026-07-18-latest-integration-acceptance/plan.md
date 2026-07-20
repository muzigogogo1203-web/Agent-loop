# Coding 牧场最新版本整合与本地验收计划

日期：2026-07-18

## 目标

把当前本地 `main`、四条尚未进入主线的 Claude 修复线，以及 2026-07-18 OpenAI 网页认证修复整合成一个可构建、可测试、可安装体验的本地版本。

## 基线

- 主线：`main` @ `3f11d087fcb4dfb13c2ecf634973f4ce0b76c650`
- 产品名：Coding 牧场
- 兼容安装路径：`/Applications/AgentLoop.app`

## 整合内容

1. `ff607885aa514b6028d5c874297245f0879bc12f`
   - release 版本号改为仅从当前提交的祖先 tag 推导。
2. `1d4605cd5c6568c0c19881155f029e7eac3c7d10`
   - 模型目录规则收敛与 OAuth 启动对账幂等化。
3. `173d5956cf8f15d05159cad474fcefc82ae1f453`
   - CLI 子进程退出后的 stdout/stderr 排空状态机收口。
4. `305a2c6d314a6ced74db7175bae519ff477e5a2e`
   - Board socket 生命周期、listener 唤醒与 SIGPIPE 处理收口。
5. `docs/collaboration/tasks/2026-07-18-openai-auth-live-fix/`
   - 预览模式 OAuth 误导修复，以及 ChatGPT backend 请求体兼容修复。

## 验收门槛

- `swift run RunTests` 权威全量测试全绿，并保存完整输出到 `verify.log`。
- `AgentLoopApp` release 构建与 `scripts/package-app.sh` 打包成功。
- 新 `.app` 签名验证通过，资源 bundle 存在。
- 旧安装版先进入可恢复备份，再更新 `/Applications/AgentLoop.app`。
- 启动安装版，确认真实生产数据库、OpenAI 网页登录状态、连接测试以及主要 Coding 牧场页面。

## 约束

- 不删除 Claude worktree 或历史安装备份。
- 不提交、不推送；整合结果保留在本地工作区供用户体验与后续 review。
- 不读取或记录任何 Keychain 凭据值。
