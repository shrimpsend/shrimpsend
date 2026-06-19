# 发帖后跟进（D+0 到 D+7 及之后）

HN 单次爆发不等于持续增长。star 留存靠稳定的 release 节奏和快速的 issue 响应。第一周决定能否把发帖热度转成一个真正活跃的项目。

## 逐日动作

| 天 | 动作 |
|---|---|
| D+0 | 监控 HN + GitHub 通知。实时修 self-host 文档坑。回复每一条有实质内容的评论。 |
| D+1 | 若 HN 表现好（>100 points），发布/刷新 GitHub Release notes，呼应大家关注的功能点。回掉过夜的评论。 |
| D+2–3 | 把 HN 高赞问题整理成可跟踪的 `docs/FAQ.md` 或置顶 Discussion。给发帖期间开的每个 issue 打标签、做分诊。 |
| D+4–7 | 72 小时内回复所有新 issue。尽快 review/合并早期 PR——首次贡献者得到快速响应才会回来。 |
| D+7 | 看指标（见下），决定是否发第二轮技术帖。 |

## Issue & PR 响应 SLA（这是留住 star 的关键）

- 新 issue：72 小时内首次响应，哪怕只是分诊。
- `good first issue` 的 PR：几天内 review；放着不管的新人 PR = 丢失的贡献者。
- 标签保持整洁（`bug`、`enhancement`、`self-hosting`、`good first issue`），让仓库读起来像在被积极维护。

## 第二轮内容（与发帖至少间隔 2 周）

不要重复发 Show HN。可以发普通 HN 帖或在别处分享：

- 「How we implement reverse-pull file transfer」—— [blog-reverse-pull.md](blog-reverse-pull.md) 的深度版。
- 「Self-hosting ShrimpSend in 10 minutes」—— 从实测修复中打磨出来的精细教程。

## 评估指标（D+7）

| 档位 | HN 结果 | GitHub 7 日增量 | 解读 |
|---|---|---|---|
| 超预期 | Top 5，300+ points | 500+ stars | 产品 + 叙事 + 运气齐了 |
| 达标 | 首页 4–8 小时，80–150 points | 150–300 stars | 独立工具的合理结果 |
| 及格 | 30–80 points | 50–150 stars | 仍有长期 SEO + 社区价值 |
| 需复盘 | <30 points | <50 stars | 重查标题、首评、README 试用门槛 |

也要看质量信号，而不只是 star：成功跑通的自托管次数、非团队账号开的 issue、首次贡献者的 PR。这些更能预测热度退去后项目是否还在长大。

## 复盘（写下来）

D+7 之后记录：哪种标题/首评框架最有效、哪个质疑最常出现、self-host 还在哪里绊人、下次最该改的一件事。把这些反哺回 README 和本套文档。
