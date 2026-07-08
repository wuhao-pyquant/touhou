# Eastern Barrage 项目交接文档

> 一款基于 Godot 4.7 的类东方弹幕射击游戏
> 文档版本: 1.0  生成日期: 2026-06-24

---

## 1. 项目概览

| 项 | 值 |
|---|---|
| 项目名称 | Eastern Barrage |
| 副标题 | Touhou-style Danmaku Shooting Game |
| 引擎 | Godot Engine 4.7 (stable) |
| 渲染后端 | `gl_compatibility` (GL2 兼容) |
| 编程语言 | GDScript (未启用严格类型) |
| 项目根目录 | `H:\claude code\godot_touhou\` |
| 主场景 | `res://scenes/main.tscn` |
| 视口分辨率 | 480 × 640 (窗口 720 × 960) |
| 启动脚本 | `启动游戏.bat` |

### 1.1 项目特点
- **单脚本架构**: 所有游戏逻辑集中在 `scripts/main.gd`(约 810 行),通过纯数据字典 + 数组模拟 ECS
- **零美术资源**: 完全使用 `draw_circle / draw_rect / draw_polyline` 等 CanvasItem API 实时绘制
- **子弹池化**: 5000 颗子弹的预分配对象池,避免运行时实例化开销
- **3 关卡 + 完整 BOSS 战**: 黎明森林 / 暮色湖面 / 猩红之夜,共 13 个 BOSS 符卡 (Spell Card)

---

## 2. 目录结构

```
H:\claude code\godot_touhou\
├── project.godot              # 项目配置 (输入映射、autoload、显示参数)
├── 启动游戏.bat                # Windows 一键启动脚本
├── autoload/
│   ├── game_manager.gd        # 全局状态机与常量 (autoload 单例)
│   └── game_manager.gd.uid    # Godot 4 资源 UID
├── scenes/
│   └── main.tscn              # 唯一场景 (Node2D 根节点 + main.gd 脚本)
├── scripts/
│   ├── main.gd                # 游戏主逻辑 (810 行,几乎所有功能都在这里)
│   └── main.gd.uid
└── .godot/                    # Godot 编辑器自动生成的缓存目录 (可忽略)
```

### 文件规模
- **总源代码**: 约 850 行 GDScript (76 + 810)
- **场景文件**: 1 个 (8 行)
- **配置**: 1 个 (85 行)
- **资源依赖**: 无外部资产 (无贴图、字体、音频、场景)

---

## 3. 依赖关系与架构

### 3.1 全局依赖图
```
┌─────────────────────────────────────────────────────────────┐
│                       project.godot                          │
│  ┌────────────────┐   ┌────────────────────────────────┐   │
│  │ run/main_scene │ → │ res://scenes/main.tscn         │   │
│  └────────────────┘   └────────────────────────────────┘   │
│  ┌────────────────┐   ┌────────────────────────────────┐   │
│  │ autoload       │ → │ GameManager (autoload 单例)    │   │
│  │                │   │   res://autoload/game_manager.gd│   │
│  └────────────────┘   └────────────────────────────────┘   │
│  ┌────────────────┐                                         │
│  │ input map      │  8 个动作: move_up/down/left/right,   │
│  │                │  shoot, bomb, focus, pause            │
│  └────────────────┘                                         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                  scripts/main.gd (Node2D)                    │
│  - 引用 autoload 单例: GameManager.*                        │
│  - 注册输入动作: move_*, shoot, bomb, pause, KEY_SHIFT      │
│  - 读取游戏配置: STAGE_MULTS, BOMB_CONFIG 等                │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 调用关系
- **`project.godot`** 通过 `[autoload]` 段将 `game_manager.gd` 注册为全局单例 `GameManager`
- **`scenes/main.tscn`** 通过 `ExtResource` 绑定到 `scripts/main.gd`
- **`main.gd`** 内可直接使用 `GameManager.xxx` 访问全局状态(autoload 特性),无需 `get_node`

### 3.3 运行时数据流
```
输入事件 (Input) 
    ↓
_process(delta) (主循环,匹配 GameManager.state)
    ↓
_update_stage / _update_boss (关卡/BOSS 状态机)
    ↓
_update_player (玩家移动、射击、炸弹、死亡无敌)
_update_bullets (子弹移动、追踪、寿命)
_update_enemies (敌人 AI、射击、死亡)
_update_items (道具下落、磁吸)
_check_collisions (碰撞、擦弹、拾取)
    ↓
queue_redraw → _draw() (CanvasItem 绘制所有实体)
```

---

## 4. 各文件功能详解

### 4.1 `project.godot` (项目配置)
**作用**: Godot 项目元数据与引擎设置。

关键段:
- **`[application]`**: 项目名 `Eastern Barrage`,版本 1.0,主场景 `res://scenes/main.tscn`
- **`[autoload]`**: 注册 `GameManager` 为全局单例(命名空间 `GameManager`)
- **`[display]`**: 视口 480×640,窗口 720×960,`canvas_items` 拉伸模式 + `keep` 长宽比
- **`[input]`**: 定义 8 个动作(支持键盘 WASD + 方向键 + Z/X/Shift/Esc)
  - `move_up` / `move_down` / `move_left` / `move_right`: WASD 或方向键
  - `shoot`: Z 键
  - `bomb`: X 键
  - `focus`: Shift 键(慢速聚焦)
  - `pause`: Esc 键
- **`[rendering]`**: GL 兼容渲染,画布纹理默认不抗锯齿 (像素风)
- **`[gdscript]`**: `analyzer/infer_declared_variable_types=false` 关闭严格类型推断,允许未标注变量

### 4.2 `autoload/game_manager.gd` (全局单例)
**作用**: 集中存放所有游戏常量、配置和运行时状态。被 `main.gd` 大量引用。

#### 4.2.1 核心常量 (屏幕与限制)
- `SCREEN_W = 480`, `SCREEN_H = 640`, `MAX_BULLETS = 5000`

#### 4.2.2 玩家参数
| 常量 | 值 | 含义 |
|---|---|---|
| `PLAYER_SPEED_HIGH` | 5.5 | 高速移动速度 |
| `PLAYER_SPEED_LOW` | 2.2 | Focus 慢速 |
| `PLAYER_HITBOX` | 2.0 | 判定点半径(碰撞) |
| `PLAYER_GRAZE` | 10.0 | 擦弹判定半径 |
| `PLAYER_FIRE_INTERVAL` | 3 | 射击帧间隔 |
| `PLAYER_INITIAL_LIVES` | 3 | 初始命数 |
| `PLAYER_INITIAL_BOMBS` | 3 | 初始炸弹数 |
| `DEATHBOMB_WINDOW` | 9 | 死亡帧窗口(可输入炸弹自救) |
| `INVINCIBLE_DURATION` | 180 | 复活无敌帧(3 秒) |
| `DEATH_POWER_DROP` | 0.8 | 死亡时掉落的灵力比例 |
| `ITEM_TOP_RATIO` | 0.2 | (备用) |

#### 4.2.3 子弹类型系统
```gdscript
enum BulletType { SPREAD = 0, LINEAR = 1, HOMING = 2 }
```
三种武器:
- **SPREAD (散射/紫)**: 范围广,扇形弹幕,伤害 2.1
- **LINEAR (贯穿/红)**: 速度快,激光感,伤害 6.0
- **HOMING (追踪/绿)**: 自瞄,缓慢跟踪,伤害 1.5

相关数组(索引对应类型):
- `BULLET_NAMES`: 显示名 `["Spread", "Pierce", "Seeker"]`
- `BULLET_COLORS`: 颜色 (紫/红/绿)
- `BULLET_DMG`: 伤害
- `POWER_THRESHOLDS = [1,5,15,30,50]`: 升级阈值(对应 0~5 级)

#### 4.2.4 炸弹配置
`BOMB_CONFIG` 是数组,每个元素是字典,包含 3 种武器各自的炸弹参数:
- `radius` (清屏半径)
- `dmg` (伤害)
- `duration` (持续帧)
- `waves` (波次数)
- `bullets` (每波弹数)
- `speed` (弹速)
- `color` (颜色)

#### 4.2.5 关卡配置
- `STAGE_NAMES`: 3 个关卡名
- `STAGE_MULTS`: 每关的难度倍率 (敌 HP / BOSS HP / 弹速)

#### 4.2.6 运行时状态变量
```gdscript
var score, graze, shared_power, bullet_type
var lives, bombs, current_stage, state
```
- `state` 是字符串状态机:`"title" | "stage" | "boss" | "stage_clear" | "final_clear" | "game_over" | "paused"`

#### 4.2.7 关键函数
- `power_level()`: 根据 `shared_power` 查表返回当前 0~5 级
- `add_power(amount)`: 加灵力并返回是否升级
- `switch_bullet_type(bt)`: 切换武器(带 clamp)
- `reset()`: 重置所有运行时状态

### 4.3 `scripts/main.gd` (主逻辑)
**作用**: 全部游戏逻辑都在这里。**约 810 行**。模块如下:

#### 4.3.1 状态变量 (行 5-28)
- **子弹池**: `bullet_pool: Array` (长度 5000)
- **敌人数组**: `enemies: Array`
- **道具数组**: `items: Array`
- **BOSS 字典**: `boss: Dictionary` (BOSS 状态机)
- **玩家状态**: `player_x/y`, `player_invincible`, `player_bombing` 等
- **关卡计时**: `stage_timer`, `stage_controller`

#### 4.3.2 生命周期
| 函数 | 行 | 作用 |
|---|---|---|
| `_ready()` | 30 | `randomize()`,预分配 5000 颗子弹,`GameManager.reset()`,显示标题 |
| `_process(delta)` | 125 | 状态机分派: title/stage/boss/stage_clear/final_clear/game_over/paused |

#### 4.3.3 子弹池与实体工厂 (行 38-115)
- `_make_bullet()`: 构造一颗子弹字典 (15 个字段)
- `_spawn_bullet_player()`: 从池中找空位,放入玩家子弹
- `_spawn_bullet_enemy()`: 放入敌人子弹
- `_spawn_item()`: 添加道具
- `_spawn_enemy()`: 添加敌人 (hp / pattern / move / move_data / strong)
- `_nearest_enemy()`: 给追踪弹找最近敌人

#### 4.3.4 状态机更新 (行 145-181)
- `_update_stage()`: 关卡阶段,处理输入、阶段波次、玩家、敌人、道具、碰撞
- `_update_boss()`: BOSS 阶段,加载 BOSS 符卡、清场逻辑
- `_enter_boss()`: 切 BOSS 前清空所有敌人和场景弹

#### 4.3.5 BOSS 系统 (行 183-402)
- `_init_boss()`: 初始化 BOSS 字典,载入对应关卡的符卡列表
- `_load_boss_cards()`: 根据关卡号载入符卡 (1/2/3 套)
- `_stage1_cards()`: 4 个符卡 (月光、星符、蝶符、神罚)
- `_stage2_cards()`: 4 个符卡 (水符、泡符、雾符、湖符)
- `_stage3_cards()`: 5 个符卡 (红符、夜符、血符、闇符、终符)

**BOSS 阶段机** (行 226-276):
```
entering (入场,120 帧缓动) 
  → active (active 中执行 _boss_fire_pattern)
    ├── declaring (符卡宣告,90 帧,期间不攻击)
    ├── active 持续
    └── hp<=0 → switching (切换符卡,40 帧间隔)
  → defeated (死亡动画,180 帧后 boss_alive=false)
```

**符卡执行器** (行 288-402):
`_boss_fire_pattern(delta)` 根据当前符卡 `c.pattern` 调用对应的弹幕函数,共 13 种:
- 月光/星符/蝶符/神罚 (Stage 1)
- 水符/泡符/雾符/湖符 (Stage 2)
- 红符/夜符/血符/闇符/终符 (Stage 3)

每种弹幕用三角函数 (cos/sin) + 数组循环生成不同视觉风格:
- 月光: 三连直线 + 环形散射
- 蝶符: 双臂对称反向旋翼 + 直线穿插
- 终符: 四层混合 (30 圆环 + 24 反向 + 5 扇形激光 + 随机)

#### 4.3.6 关卡波次 (行 405-470)
- `_stage_waves()`: 路由到对应关卡
- `_waves_s1/2/3()`: 每个关卡 15~18 个时间点触发的敌群生成
- 每个生成事件指定 `pattern` (射击模式) 和 `move` (移动模式)

**敌人射击模式** (`_update_enemies` 行 605-621):
- `aimed`: 瞄准玩家
- `spread`: 扇形 3 发
- `ring`: 12 向圆环
- `double_spread`: 5 发宽扇
- `downward`: 垂直下落
- `wave`: 波浪形 5 发
- `spiral`: 8 向螺旋

**敌人移动模式** (行 585-597):
- `straight`: 直线
- `sine`: 横向正弦摆动
- `circle`: 绕中心点圆周
- `enter_and_stop`: 入场后悬停微抖

#### 4.3.7 玩家系统 (行 472-563)
- `_update_player()`: 移动、聚焦、射击、炸弹、死亡无敌、死亡炸弹窗口
- 移动: `dx*speed*delta*60` (即 60 FPS 等价,所有速度都按帧归一化)
- 边界限制: `x ∈ [16, 464]`, `y ∈ [16, 624]`
- 射击: `_shoot()` 根据 `power_level()` 和 `bullet_type` 调用 `_shoot_spread/_linear/_homing`
- 死亡炸弹 (Deathbomb): 被击中后 `DEATHBOMB_WINDOW = 9 帧` 内按 X 可自救
- 炸弹: `_start_bomb()` 减少 `bombs`,启动 `_update_bomb()`
- `_update_bomb()`: 半径扩张清屏 + 周期性向四周发射玩家子弹

#### 4.3.8 子弹与敌人更新 (行 565-621)
- `_update_bullets()`: 移动、寿命、边界,**追踪弹** 用角差钳制算法 (`fposmod(goal - cur + PI, TAU) - PI`)
- `_update_enemies()`: 移动、射击计时、死亡处理

#### 4.3.9 道具系统 (行 623-645)
- `_update_items()`: 漂浮上升 → 自由下落 → 玩家在 y<128 + 按 Shift 时磁吸
- 五种道具类型: `power` / `point` / `bomb_refill` / `life` / 武器切换
- 边界: `x ∈ [11, 469]`, y>670 消失

#### 4.3.10 碰撞检测 (行 652-687)
- 玩家弹 vs 敌人/ BOSS
- 敌人弹 vs 玩家 (`PLAYER_HITBOX`)
- 擦弹 (`PLAYER_GRAZE`): 每帧每弹最多 1 分 + 10 积分
- 道具拾取

#### 4.3.11 道具掉落与收集 (行 689-719)
- `_drop_item()`: 强敌必掉 `bomb_refill`,普通敌按概率掉 5 种之一
- `_collect()`: 切换武器 / 加灵力 / 加分 / 补命补弹 (上限: 命 6, 弹 5)

#### 4.3.12 渲染 `_draw()` (行 721-810)
全部使用 `CanvasItem` 实时绘制:
1. **道具** (行 723-743): 红圆=power, 蓝菱=point, 橙星=bomb_refill, 粉方=life, 六边形=武器
2. **敌人** (行 745-756): 紫圆 + 装饰线 + 眼睛,强敌带金色三角冠
3. **子弹** (行 758-763):
   - 玩家弹: 半透明外圈 + 白核
   - BOMB 弹: 半透明
   - 敌人弹: 外发光 + 主色 + 黑边 + 白核
4. **BOSS** (行 765-777): 六边形 + 白心红核 + HP 条 (左上角)
5. **玩家** (行 779-790): 头(浅肤)+ 身(深红)+ 围腰(深紫)
   - Focus 时画判定点+擦弹圈
   - 炸弹时画清屏范围
6. **标题屏** (行 792-801): 蓝色圆+文字
7. **HUD** (行 803-810): 左上角 Score/Graze/Shot Lv, 右上角 Life♥/Bomb◆, 底部关卡名

---

## 5. 数据结构参考

### 5.1 子弹字典
```gdscript
{
  "active": false,        # 是否在用
  "x": 0.0, "y": 0.0,     # 位置
  "vx": 0.0, "vy": 0.0,   # 速度 (单位: 像素/帧 @60FPS)
  "radius": 6.0,          # 判定半径
  "color": Color.RED,     # 颜色
  "type": "circle",       # "player" | "bomb" | "circle" | "rice" | "arrow" | "laser"
  "lifetime": 600.0,      # 寿命(帧)
  "age": 0.0,             # 已存时间
  "damage": 1.0,          # 伤害
  "homing": false,        # 是否追踪
  "btype": -1             # 武器类型索引 (-1 表示敌人弹)
}
```

### 5.2 敌人字典
```gdscript
{
  "alive": true, "dying": false, "death_timer": 0.0,
  "x": 0, "y": 0, "hp": 5, "max_hp": 5,
  "radius": 14, "strong": false,
  "vx": 0, "vy": 1.5, "move_timer": 0,
  "move": "straight", "move_data": {},
  "pattern": "aimed", "shoot_timer": 30, "shoot_phase": 0
}
```

### 5.3 BOSS 字典
```gdscript
{
  "x": 240, "y": -60, "hp": 600, "max_hp": 600, "radius": 28,
  "phase": "entering",         # entering | active | switching | defeated
  "timer": 0, "entered": false,
  "sway": 0,                   # 浮动用
  "declaring": false, "declare_timer": 0,
  "card_name": "", "cards": [...], "card_idx": 0,
  "card_hp": 0, "card_timer": 0, "card_shot": 0,
  "flash": 0, "rot": 0, "anim": 0, "alive": true
}
```

### 5.4 道具字典
```gdscript
{
  "alive": true, "collected": false,
  "x": 0, "y": 0, "type": "power", "radius": 9,
  "vy": -2.5, "vx": 0, "floating": true, "target_y": 120,
  "sway": 0, "birth": 15, "anim": 0
}
```

---

## 6. 输入映射表

| 动作 | 按键 1 | 按键 2 |
|---|---|---|
| `move_up` | W | ↑ |
| `move_down` | S | ↓ |
| `move_left` | A | ← |
| `move_right` | D | → |
| `shoot` | Z | - |
| `bomb` | X | - |
| `focus` | Shift (原生键) | - |
| `pause` | Esc | - |

> ⚠️ 注意: `focus` 在 `project.godot` 中**未**配置键位 (其 action 为空),实际游戏中使用 `Input.is_key_pressed(KEY_SHIFT)` 直接检测。这是个小 bug,可加 `physical_keycode: 4194325` (Shift) 修复。

---

## 7. 启动与运行

### 7.1 一键启动
直接双击 `启动游戏.bat`,它会:
1. 检查 Godot 4.7 是否存在于 `C:\Users\e\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7-stable_win64.exe`
2. 用 `start "" "godot.exe" --path "%~dp0"` 启动项目 (Godot 编辑器模式)

> 注意: 用 `--path` 启动会打开 Godot 编辑器,需要再点右上角 ▶ 运行游戏。如果想直接运行,在 `godot.exe` 后加 `--path "%~dp0" --main-pack` 或加 `--quit-after 1` 之类的参数,或使用 `godot --path .` 后的 F5。

### 7.2 命令行启动
```bat
"C:\path\to\Godot_v4.7-stable_win64.exe" --path "H:\claude code\godot_touhou"
```

### 7.3 直接以游戏模式运行 (跳过编辑器)
```bat
"...\Godot.exe" --path "H:\claude code\godot_touhou" scenes/main.tscn
```

---

## 8. 已知问题 / 改进建议

1. **`focus` 输入未注册** - `project.godot` 中 `focus` 动作的 `events` 数组为空,游戏用 `Input.is_key_pressed(KEY_SHIFT)` 直接检测(已能工作,但映射不完整)。
2. ~~未实现音效/音乐~~ **已实现**: 见第 11 节。
3. **关卡选择 / 暂停菜单** - 暂停只切状态,没有 UI。
4. **没有玩家图形素材** - 全部用代码画,简单但无特色。
5. **没有存档系统** - 每次重开 reset。
6. **代码未模块化** - main.gd 已增至 ~840 行,弹幕函数可以拆分到 `scripts/boss_patterns.gd`。
7. **`_update_stage` 中 `stage_controller.boss_spawned` 在达到 `boss_time` 时被置 true,但没有立即调用 `_enter_boss`**,必须等所有敌人被清完才进入 BOSS,符合设计。
8. **没有重放模式/分数上传**。
9. **`_show_title()` 只是设置状态,真正的标题 UI 在 `_draw()` 里** - 状态与渲染耦合,迁移到场景树会更清晰。

---

## 11. 修订记录 (2026-06-24 增补)

### 11.1 修复: 进游戏后按键无反应
**根因**: `scripts/main.gd:485` `_update_player()` 引用了不存在的常量:
```gdscript
var speed: float = GameManager.PLAYER_LOW_SPEED if focus else GameManager.PLAYER_HIGH_SPEED
```
但 `autoload/game_manager.gd:10-11` 中的真实名字是 `PLAYER_SPEED_LOW` / `PLAYER_SPEED_HIGH`。
GDScript 在运行期首次执行该函数时抛 "Identifier not found" 错误,**整函数 `_update_player` 被静默中断**,导致玩家既不移动也不射击——看起来像"按键无反应"。
**修复**: 把 `main.gd:485` 改为 `GameManager.PLAYER_SPEED_LOW if focus else GameManager.PLAYER_SPEED_HIGH`。

### 11.2 新增: 音效与背景音

新增文件:
- `autoload/audio_manager.gd` (新 autoload 单例 `AudioManager`,API: `play_bgm(key)/stop_bgm()/fade_bgm(target_db,time)/play_sfx(name,vol_db)/bgm_stage_mid(n)/bgm_stage_boss(n)`)
- `audio/bgm/*.wav` × 6 (3 关道中 + BOSS,每个 190~196 秒,无缝循环,完整 A-A-B-A'-C-A 多段结构,非几小节循环)
- `audio/sfx/*.wav` × 4 (shoot / bomb / kill / hit)
- `tools/gen_audio.py` (numpy 向量化的程序化生成脚本,可重跑)

新增 autoload 注册 (`project.godot`):
```
[autoload]
GameManager="*res://autoload/game_manager.gd"
AudioManager="*res://autoload/audio_manager.gd"
```

SFX/音乐触发点:
| 事件 | 文件:行 | 调用 |
|---|---|---|
| 开局/进关卡/换关 | `_start_game` / `_advance_stage` | `AudioManager.bgm_stage_mid(N)` |
| 进 BOSS | `_enter_boss` | `AudioManager.bgm_stage_boss(N)` |
| 关卡通过(待续) | `_update_boss` | `AudioManager.fade_bgm(-12, 0.6)` |
| 通关 / 陨命 GameOver | `_update_boss` / `_update_stage` | `AudioManager.fade_bgm(-30, 0.8~1.0)` |
| 回标题 | `_show_title` | `AudioManager.stop_bgm()` |
| 玩家开火 | `_shoot` | `AudioManager.play_sfx("shoot", -12)` (已节流到每 2 发响起一声) |
| 释放炸弹 | `_start_bomb` | `AudioManager.play_sfx("bomb", -4)` |
| 击破普通敌 / 强敌 | `_check_collisions` | `AudioManager.play_sfx("kill", -8~-6)` |
| BOSS 符卡通过 / 超时 | `_boss_card_clear/timeout` | `AudioManager.play_sfx("kill", -5~-7)` |
| 玩家被弹幕击中 | `_check_collisions` 内 `player_just_hit=true` 处 | `AudioManager.play_sfx("hit", -2)` |

实现要点:
- **BGM 循环**: 载入时把 `AudioStreamWAV.loop_mode = LOOP_FORWARD`,循环区为整段(0..0),符合"完整一首 3 分钟以上纯音乐"的要求,而非动机小循环。
- **SFX 池**: 8 个 `AudioStreamPlayer` 轮流复用,防止高频射击音叠死自己。
- **道中 vs BOSS**: 3 关 × 2 段 = 6 个独立曲目,BOSS 战用更快的 BPM(132~145)+ 硬鼓 + 锯齿波,道中用慢 BPM(98~112)+ 软鼓 + 正弦/三角波/拨弦,听感差异明显。
- **音频规格**: 22050Hz 单声道 16-bit PCM,共 6 曲约 19 分钟,4 SFX 共约 2 秒,体积小(整套 ~30MB)。
- **淡入淡出**: `fade_bgm()` 内用 `create_tween()` 做 linear ramp。

---

## 9. 二次开发指南

### 9.1 添加新 BOSS 符卡
1. 在 `main.gd:194-217` 的对应 `_stage1/2/3_cards()` 数组里加一项:
   ```gdscript
   {"name":"符卡名","hp":1200,"time":30,"pattern":"your_pattern"}
   ```
2. 在 `_boss_fire_pattern` (行 288) 的 match 加 `"your_pattern": _bullets_your_pattern(mult)`
3. 实现函数:
   ```gdscript
   func _bullets_your_pattern(mult: float):
       if int(boss.card_shot) % 6 == 0:
           for i in range(N):
               _spawn_bullet_enemy(boss.x, boss.y, cos(...)*spd*mult, sin(...)*spd*mult, radius, color, type)
   ```

### 9.2 添加新敌人射击模式
在 `_update_enemies` (行 605) match 加 case。

### 9.3 添加新关卡
1. 在 `GameManager.STAGE_NAMES` 加名,`STAGE_MULTS` 加倍率
2. 在 `main.gd:84 _load_stage` 加 case
3. 实现 `_waves_s4(timer)` 波次函数
4. 在 `_stage_waves` (行 406) 加路由
5. 在 `_load_boss_cards` (行 188) 加 `_stage4_cards()` 并实现

### 9.4 切换武器
游戏内拾取对应道具即可,无快捷键。

---

## 10. 关键代码位置速查

| 功能 | 文件:行 |
|---|---|
| 主循环 | `main.gd:125` |
| 玩家移动 | `main.gd:472-492` |
| 玩家射击 | `main.gd:502-539` |
| 炸弹逻辑 | `main.gd:541-563` |
| BOSS 状态机 | `main.gd:226-276` |
| BOSS 符卡定义 | `main.gd:194-217` |
| 弹幕函数群 | `main.gd:307-402` |
| 关卡波次 | `main.gd:411-470` |
| 敌人 AI | `main.gd:579-621` |
| 道具系统 | `main.gd:623-645` |
| 碰撞/擦弹 | `main.gd:652-687` |
| 渲染 | `main.gd:721-810` |
| 标题屏 | `main.gd:793-801` |
| HUD | `main.gd:803-810` |
| 全局常量 | `game_manager.gd:5-46` |
| 状态变量 | `game_manager.gd:48-56` |

---

**文档结束。** 接手者应:① 启动游戏熟悉手感 ② 读 `main.gd:721-810` 理解渲染 → ③ 读 `_update_stage/boss` 理解主循环 → ④ 读 `game_manager.gd` 理解配置 → ⑤ 修改/扩展。
