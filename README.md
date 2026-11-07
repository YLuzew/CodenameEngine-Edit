# CodenameEngine-Edit

Codename Engine 源码的**性能修改版**，主要目标是 Android 端的加载速度。

原版仓库：<https://github.com/CodenameCrew/CodenameEngine>
本仓库只放 `source/` 与编译配置，不含 `assets/`（303M）和 `art/`（164M）。

---

## 为什么要改

同一台手机上，Codename Engine 进一首歌要等的时间明显长于 Psych Engine / V-Slice。
不是音频解码慢，是 CNE 独有的一套机制叠加起来：

### 1. 运行时虚拟文件系统 + 逐段大小写匹配

`Paths.getExistingPath()` 每次查一个资源：

```
Assets.exists("assets/xxx")        ← Android 上是真文件系统调用
  ↓ 失败
Flags.PATHS_UNIX_FIX 逐段大小写匹配
  ↓ 每段都调 assetsTree.getFiles() / getFolders()
  ↓ 那两个函数遍历**所有已挂载的库**，内部 pushOnce 是 O(n²)
```

一首歌进 `PlayState` 要查上千次路径，其中大量是「本曲根本没有这个文件」的失败查询
（脚本、事件、note 图集、难度变体……）。**每一次失败都在重复同一趟全库遍历。**

Psych Engine 的 `Paths` 是直接字符串拼接，不查文件系统。

**改动**：`getExistingPath` 结果缓存，命中和未命中都缓存。

### 2. 切 state 就清缓存

`Flags.PATHS_CACHE_RESET_ON_SWITCH_STATE` 默认 `true`，`GlobalScript` 每次 state
切换都调 `resetAssetPathCache()`。

结果：**每次进歌都是冷缓存**，上面那套开销一次不落全吃。

**改动**：默认改 `false`。mod 重载走 `ModsFolder.reloadMods()` → `MainState` →
`AssetsLibraryList.reset()` → 仍会清。

### 3. 谱面被解析两次

`FreeplayState` 选歌时 `Chart.parse()` 一次（读 meta / 难度 / BPM），
`PlayState.create()` 之前又 `Chart.parse()` 一次。
每次都完整走 json 读取 + 转换（LEGACY 要逐 section 逐 note 转）+ meta 二次解析 + events。

**改动**：`Chart.parse` 结果缓存（键 = 歌名|难度|变体），`clearChartCache()` 手动清。

### 4. 每首歌加载 5 个脚本目录并逐个编译 HScript

`songs/<歌>/scripts`、`songs/<歌>/scripts/<难度>/`、`data/charts/`、`songs/`，
再加 `data/notes/<每个类型>`、`data/events/<每个用到的事件>`。
每个脚本都要 `parser.parseString()` 解析一遍。

Psych Engine 默认没有脚本，V-Slice 也没有——**这一块是 CNE 独有的固定成本。**

（本仓库暂未动这块，Expr 复用的风险高于收益。）

---

## 改了哪些文件

| 文件 | 改动 |
| --- | --- |
| `source/funkin/backend/assets/Paths.hx` | `getExistingPath` 加命中/未命中双向缓存；新增 `resetExistingPathCache()`、`getExistingPathCacheStats()` |
| `source/funkin/backend/assets/AssetsLibraryList.hx` | `resetAssetPathCache()` 里同步清 `Paths` 的缓存 |
| `source/funkin/backend/system/Flags.hx` | `PATHS_CACHE_RESET_ON_SWITCH_STATE` 默认 `true → false` |
| `source/funkin/backend/scripting/GlobalScript.hx` | state 切换时连带清 `Paths.resetExistingPathCache()` |
| `source/funkin/backend/chart/Chart.hx` | `Chart.parse` 结果缓存；新增 `clearChartCache()` |

原始文件都留了 `.orig` 备份。

---

## 怎么用

把本仓库的 `source/` 覆盖到你的 CNE 工程根目录（与 `assets/`、`art/` 同级），
然后照常 `lime build android`。

想在运行中查缓存效果：

```haxe
trace(Paths.getExistingPathCacheStats());   // hit=... miss=...
```
