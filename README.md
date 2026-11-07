# CodenameEngine-Edit

Codename Engine（橙汁 / CNE）的一份可编译副本，改动集中在 **Android 进歌加载性能**，并附带一条能直接出 APK 的 GitHub Actions 流水线。

基线：`/storage/emulated/0/.源码/橙汁的cne`（橙子的主仓库源码树，非 git 仓库）。

---

## 1. 引擎改动（`source/`，原始文件留 `.orig`）

进歌比 PE / V-Slice 慢一个数量级的四个原因，改了前三个，第四个（HScript 编译）故意没动。

### 1.1 `source/funkin/backend/assets/Paths.hx`

`getExistingPath()` 每次先 `Assets.exists()`（Android 上是真文件系统调用），失败后按 `Flags.PATHS_UNIX_FIX` 逐段做大小写模糊匹配，每段都调 `assetsTree.getFiles/getFolders` —— 那两个函数遍历**所有已挂载的资源库**，内部 `pushOnce` 是 O(n²)。而进一首歌要查上千次路径，其中大量是「本曲根本没有这个文件」的失败查询。

加了双向缓存：

```haxe
static var __existingPathCache:Map<String, String> = [];
static var __existingPathMiss:Map<String, Bool> = [];

public static function resetExistingPathCache():Void { ... }
public static function getExistingPathCacheStats():String { ... }  // 用 Lambda.count 统计

// getExistingPath() 内部
var cacheKey = (nullFail ? "1" : "0") + "|" + prefix + path;
```

命中与未命中都缓存。

### 1.2 `source/funkin/backend/assets/AssetsLibraryList.hx`

`resetAssetPathCache()` 末尾补一句 `Paths.resetExistingPathCache();`，让两套缓存一起清理。

### 1.3 `source/funkin/backend/system/Flags.hx`

`PATHS_CACHE_RESET_ON_SWITCH_STATE` 由 `true` 改为 `false`。原来是每次切 state 都清一次缓存，等于进歌永远冷缓存。

### 1.4 `source/funkin/backend/scripting/GlobalScript.hx`

清缓存处改成受开关控制：

```haxe
if (Flags.PATHS_CACHE_RESET_ON_SWITCH_STATE) {
    Paths.assetsTree.resetAssetPathCache();
    Paths.resetExistingPathCache();
}
```

### 1.5 `source/funkin/backend/chart/Chart.hx`

`parse()` 无缓存：FreeplayState 选歌解析一次，PlayState.create() 之前又解析一次，每次完整走一遍 json 读取 + LEGACY 逐 note 转换 + meta 二次解析 + events 读取。

拆成两层：

```haxe
static var __chartCache:Map<String, ChartData> = [];
public static function clearChartCache():Void { ... }

public static function parse(songName:String, difficulty:String, ?variant:String) {
    var cacheKey = songName + "|" + difficulty + "|" + (variant == null ? "" : variant);
    ...
}
private static function __parseUncached(songName:String, difficulty:String, ?variant:String) { ... 原实现 ... }
```

> 第四条（每首歌扫 5 个脚本目录、逐个 `parser.parseString()` 编译 HScript）没有改。复用 hscript 的 Expr 树风险高于收益 —— 一旦出错是全游戏脚本一起挂。

**这些是引擎改动，必须重编 APK 才生效，跟 mod 热重载是两条线。**

---

## 2. Android 构建

`.github/workflows/build-android.yml`，参数照抄官方移动端仓库 [azmlpoh/CodenameEngine-Mobile](https://github.com/azmlpoh/CodenameEngine-Mobile) 的 `android.yml`。

**手动触发**：Actions → Build Android APK → Run workflow。产物在 artifact 里（约 218 MB 的 release APK）。

### 踩过的三个坑

**坑 1：`#if desktop` 在 CI 上恒为真**

`commandline/commands/Setup.hx:67`：

```haxe
var libFile = #if desktop "./building/libs.xml" #else './building/libs-mobile.xml' #end;
```

GitHub runner 是 Linux，`desktop` 为真，跑 `cne setup` 会装桌面那套依赖。官方 CI 没管这件事（他们的 `libs.xml` 与 `libs-mobile.xml` 只在 lime 一行不同），这里跟随官方，直接 `Main setup -si`。

**坑 2：`Compiler.getBuildTarget()` 返回 `linux`**

`commandline/commands/Compiler.hx` 按 `Sys.systemName()` 决定构建目标，Linux 上是 `linux`，所以 `cne release` 在 CI 里永远编桌面版。编 Android 要直接 `haxelib run lime build android`。

**坑 3（真凶）：foxlite 与 openfl old 分支互斥**

```
ERROR foxlite/lights/FoxLightData.hx:181
  openfl.geom.Matrix3D has no field transformVectorToOutput
ERROR foxlite/math/FoxMathUtil.hx:358
  openfl.geom.Vector3D has no field crossProductToOutput
```

- `building/libs-mobile.xml` 把 openfl 钉在 `CodenameCrew/cne-openfl` 的 **old** 分支；`old` 分支的 `Matrix3D`/`Vector3D` 没有这两个方法（只有 `master` 有）。
- 同一份清单里又装了 `foxlite`（`dwdvIl/foxlite`，无 ref → 拉最新），最新 foxlite 就是拿这两个方法编译的。
- **两者永远编不过。** 桌面 `libs.xml` 不装 foxlite，所以桌面一直好好的 —— 这就是「原来构建成功、现在不成功」的原因。

处理（与官方移动端仓库一致）：删掉 `libs-mobile.xml` 的 foxlite 行，删掉 `project.xml` 的 `<haxelib name="foxlite" if="THREE_D_SUPPORT"/>`。源码里三处 foxlite 引用都是条件编译，define 消失后自动跳过：

```
source/funkin/backend/system/macros/Macros.hx:28   #if foxlite
source/funkin/backend/scripting/Script.hx:77       #if (THREE_D_SUPPORT && foxlite)
source/hscript/Config.hx:26                        #if foxlite
```

`away3d` 保留 —— 官方也没有删。

### artifact 下载

artifact 走 `actions/upload-artifact@v4`，**需要登录 GitHub 才能下载**，匿名 API 拉不到。

---

## 3. 目录

完整工程，1607 个文件 / 473 MB，`art/`（164M 的 `.fla` 源素材）也在里面。

```
assets/     1100 个  303M
source/      405 个  3.5M
art/          73 个  164M
building/     10 个   48K   ← 编译脚本与依赖清单
commandline/   6 个   43K   ← cne setup / build 命令实现
addons/ mods/ adb/ key.keystore/ project.xml/ shell.nix/ ...
```
