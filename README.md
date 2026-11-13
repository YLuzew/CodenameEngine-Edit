# CodenameEngine-Edit

Codename Engine（CNE）的一份可编译副本，改动集中在 **Android 进歌加载性能** 与 **模组自定义 state 加载**，附带一条能直接出 APK 的 GitHub Actions 流水线。

上游基线：[`azmlpoh/CodenameEngine-Mobile`](https://github.com/azmlpoh/CodenameEngine-Mobile)（移动端维护者的仓库，不是官方；官方是 [`CodenameCrew/CodenameEngine`](https://github.com/CodenameCrew/CodenameEngine)）。

构建参数照它的 `.github/workflows/android.yml`。

---

## 1. 引擎改动（`source/`，原始文件留 `.orig`）

进歌比 PE / V-Slice 慢一个数量级，原因有四条，改了前三条，第四条故意没动。

### 1.1 `Paths.hx` —— 路径存在性查询缓存

`getExistingPath()` 每次先 `Assets.exists()`（Android 上是真文件系统调用），失败后按 `Flags.PATHS_UNIX_FIX` 逐段做大小写匹配，每段都调 `assetsTree.getFiles/getFolders` —— 那两个函数遍历**所有已挂载的资源库**，内部 `pushOnce` 是 O(n²)。进一首歌要查上千次路径，大部分是「本曲根本没有这个文件」的失败查询（脚本、事件、note 图集、难度变体…）。

**只缓存命中，不缓存未命中。**

```haxe
static var __existingPathCache:Map<String, String> = [];

public static function resetExistingPathCache():Void { ... }
public static function getExistingPathCacheStats():String { ... }  // Lambda.count 统计

// getExistingPath() 内部
final cacheKey = (nullFail ? "1" : "0") + "|" + prefix + path;
if (__existingPathCache.exists(cacheKey)) return __existingPathCache.get(cacheKey);
```

早期版本还缓存过未命中（`__existingPathMiss`），**已全部删除**。理由：缓存键里没有库上下文，而模组是引擎启动之后才挂载的 —— 启动期查不到的路径会被永久记死，模组挂上来以后依然返回「不存在」。只缓存命中就绕开了这个问题，代价是失败查询每次重查（这部分本来就是少数）。

### 1.2 `Chart.hx` —— 谱面解析缓存

`parse()` 无缓存时，FreeplayState 选歌解析一次，PlayState 之前又解析一次，每次完整走 json 读取 + LEGACY 逐 note 转换 + meta 二次解析 + events 读取。

```haxe
static var __chartCache:Map<String, ChartData> = [];
public static function clearChartCache():Void { ... }
private static function __parseUncached(songName:String, difficulty:String, ?variant:String) { ... 原实现 ... }
// 缓存键：songName|difficulty|variant
```

### 1.3 `AssetsLibraryList.hx` —— 缓存失效

清缓存放在 `resetAssetPathCache()` 里，**不放在 `addLibrary()` 里**：

```haxe
public function resetAssetPathCache() {
    ...
    Paths.resetExistingPathCache();
}

public function addLibrary(lib:AssetLibrary, ?tag:AssetSource, ?addTransLib:Bool = true) {
    libraries.insert(0, lib);   // 首行就是登记，前面不允许插任何可能抛异常的副作用
    ...
}
```

`addLibrary()` 是「把库登记进资产树」这个动作本身。在它前面塞清缓存调用，一旦那里抛异常，`libraries.insert` 就不会执行 —— 库压根没挂上，症状是**所有模组全黑、原版正常**。这个形状在 `9f83cf0f` 上并不存在（那版 `addLibrary()` 首行就是 insert），所以它不是黑屏的原因，但这条纪律要留着。

### 1.4 `Flags.hx` / `GlobalScript.hx`

`PATHS_CACHE_RESET_ON_SWITCH_STATE` 改成 `false`（原版是 `true`）：

```haxe
public static var PATHS_CACHE_RESET_ON_SWITCH_STATE:Bool = false;
```

`GlobalScript.hx` 里那段清缓存改成受开关控制，两个缓存一起清：

```haxe
if (Flags.PATHS_CACHE_RESET_ON_SWITCH_STATE) {
    Paths.assetsTree.resetAssetPathCache();
    Paths.resetExistingPathCache();
}
```

原来每次切 state 都清一遍，进歌时必然是冷缓存 —— 缓存等于没加。改成 `false` 之后，缓存跨 state 存活；模组重载时由 `resetAssetPathCache()` 兜底。

### 1.5 `MusicBeatState.hx` —— 单文件 state 脚本兜底（关键修复）

原版 `loadScript()` 只认一种布局：

```haxe
for (i in funkin.backend.assets.ModsFolder.getLoadedMods()) {
    var path = Paths.script('data/states/${scriptName}/LIB_$i');
    var script = Script.create(path);
    if (script is DummyScript) continue;
    ...
}
```

`LIB_$i` 里的 `$i` 是模组名原样（含空格和大小写，例如 `Indie Cross CNE port`）。这个路径由 `ModsFolderLibrary.__parseAsset()`（`ModsFolderLibrary.hx:130-143`）重写成 `data/states/<StateName>.hx` —— 也就是说，**模组必须提供 `LIB_<模组名>.hx` 这种形态**，单文件才会被找到。

实际生态里绝大多数模组用的是单文件 `data/states/IndieCrossMainMenu.hx`，`LIB_` 文件一个都没有。结果路径永远不存在 → `Script.create` 拿到 `DummyScript` → 脚本不加载 → state 自己又不绘制任何东西 → **纯黑（FPS 照跑）**。原版 state 不受影响，因为它们有 C++ 侧的实现。

加一层兜底：

```haxe
if (stateScripts.scripts.length == 0) {
    var plainPath = Paths.script('data/states/${scriptName}');
    var plainScript = Script.create(plainPath);
    if (!(plainScript is DummyScript)) {
        plainScript.remappedNames.set(plainScript.fileName, plainScript.fileName);
        stateScripts.add(plainScript);
        plainScript.load();
    }
}
```

一次修所有模组，不动模组文件。`LIB_` 布局仍然优先，向后兼容。

### 未改动

每首歌扫 5 个脚本目录（`songs/<歌>/scripts`、`scripts/<难度>/`、`data/charts/`、`songs/`）+ `data/notes/<类型>` + `data/events/<事件>`，每个脚本 `HScript.hx:73` 都要 `parser.parseString()` 编译一遍。复用 hscript 的 Expr 树风险高于收益 —— 一旦出错是全游戏脚本一起挂。

**这些是引擎改动，必须重编 APK 才生效，跟 mod 热重载是两条线。**

---

## 2. Android 构建

`.github/workflows/build-android.yml`。手动触发：Actions → Build Android APK → Run workflow；推 `main` 也会触发（`art/**` 和 `**/*.md` 除外）。

`concurrency` 开了 `cancel-in-progress: true`，同一个 ref 上重复触发会把前一个 run 取消 —— 看到 `cancelled` 通常就是这个，不是失败。

### 踩过的坑

**坑 1：`#if desktop` 在 CI 上恒为真**

`commandline/commands/Setup.hx:67`：

```haxe
var libFile = #if desktop "./building/libs.xml" #else './building/libs-mobile.xml' #end;
```

GitHub runner 是 Linux，`desktop` 为真，`cne setup` 装的是桌面那套依赖。参照移动端仓库的做法，直接 `haxe -cp commandline -D analyzer-optimize --run Main setup -si`（不传 `--lib`）。

**坑 2：`Compiler.getBuildTarget()` 返回 `linux`**

`commandline/commands/Compiler.hx` 按 `Sys.systemName()` 决定目标，Linux 上是 `linux`，所以 `cne release` 在 CI 里永远编桌面版。编 Android 要直接 `haxelib run lime build android`。

**坑 3（真凶）：foxlite 与 openfl old 分支互斥**

```
ERROR foxlite/lights/FoxLightData.hx:181  openfl.geom.Matrix3D has no field transformVectorToOutput
ERROR foxlite/math/FoxMathUtil.hx:358     openfl.geom.Vector3D has no field crossProductToOutput
```

| | openfl | foxlite |
|---|---|---|
| `building/libs.xml`（桌面） | `cne-openfl` ref=`old` | **不装** |
| `building/libs-mobile.xml`（Android） | `cne-openfl` ref=`old` | **装了，拉最新** |

最新 foxlite 要的两个方法只有 openfl **master** 有，`old` 分支一处都没有 —— 这个组合永远编不过。桌面不装 foxlite，所以桌面一直正常；「原来构建成功、现在不成功」是把两套清单搞混了。

处理（与移动端仓库一致）：删掉 `libs-mobile.xml` 的 foxlite 行、`project.xml` 的 `<haxelib name="foxlite" if="THREE_D_SUPPORT"/>`。源码三处引用全是条件编译，define 消失后自动跳过：

```
source/funkin/backend/system/macros/Macros.hx:28   #if foxlite
source/funkin/backend/scripting/Script.hx:77       #if (THREE_D_SUPPORT && foxlite)
source/hscript/Config.hx:26                        #if foxlite
```

`away3d` 保留。

**坑 4：上游 Releases 504 会打断 `setup-haxe`**

`krdlab/setup-haxe@v2` 从 `github.com/HaxeFoundation/neko/releases` 拉包，那个域名偶发 504，run 会在 31 秒内挂掉，报 `curl: (22) The requested URL returned error: 504`。haxe / neko 的官方下载源最终都落到 GitHub Releases，换镜像绕不开。

处理：`setup-haxe` 加 `continue-on-error: true` + `id`，失败时走 apt 源兜底：

```yaml
      - name: Haxe
        id: setup_haxe
        uses: krdlab/setup-haxe@v2
        continue-on-error: true
        with:
          haxe-version: ${{ env.HAXE_VERSION }}

      - name: Haxe 兜底（绕开 GitHub Releases 504）
        if: steps.setup_haxe.outcome == 'failure'
        run: |
          sudo apt-get update -qq
          sudo apt-get install -y haxe neko
```

**坑 5：产物签名**

CI 里加了一步 `apksigner verify --print-certs`，验不过就用仓库自带的 `key.keystore` 兜底重签（alias `psychport`）。当前产物签名：

```
V2 Signer: CN=Lily Ross, O=MobilePorting
SHA-256: c60160598c765ae2702f36e706a6214360a897038b087375c6a6520ef181a867
```

**versionCode 会递增**。手机上已装版本号更高时，系统会静默拒绝降级安装 —— 装完看着没变化，其实是没装进去。

**artifact 下载**：单连接约 20 KB/s，229 MB 要三小时。48 路 range 并发能到分钟级。三个必须遵守的点：

1. 用 API 返回的精确 `size_in_bytes` 切块 —— 同一 workflow 两次构建差几百字节，沿用旧值会让所有块错位。
2. SAS 链接 `se=` 只有约 10 分钟，**取一次链接就要把所有块跑完**，不要边取边下拖时间。
3. 合并必须按数字序 `for i in $(seq 0 47); do cat "p$i"; done`。用 `cat p*` 会按字母序把 `p10` 排在 `p2` 前，文件大小完全正确但 zip 打不开（`BadZipFile`）。

**CNE 的逻辑不在 `classes.dex`**，编译进 `lib/arm64-v8a/libApplicationMain.so`（约 94 MB）。要验证某个改动有没有真的编进 APK，抽 so 后 `strings | grep`。

---

## 3. 目录

完整工程，1607 个文件 / 473 MB。

```
assets/     1100 个  303M
source/      405 个  3.5M
art/          73 个  164M
building/     10 个   48K   ← 编译脚本与依赖清单
commandline/   6 个   43K   ← cne setup / build 命令实现
addons/ mods/ adb/ key.keystore/ project.xml/ shell.nix/ ...
```

---

## 4. 改动记录

| 日期 | 内容 |
|---|---|
| 2026-11-07 | 初版：路径缓存、谱面缓存、缓存失效、foxlite 剔除、CI 出包 |
| 2026-11-08 | `Paths` 去掉未命中缓存，只留命中；`PATHS_CACHE_RESET_ON_SWITCH_STATE` 改 `false` |
| 2026-11-13 | `setup-haxe` 加 504 兜底（apt）；`MusicBeatState.loadScript` 加单文件 state 脚本兜底，修「所有模组自定义 state 黑屏」 |
