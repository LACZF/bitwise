# bitwise - HarmonyOS (鸿蒙) 版

程序员位运算 / 进制转换计算器。本目录是 **Python/tkinter 版 `bitwise_calculator.py` 的 ArkTS/ArkUI 原生移植**，使用 HarmonyOS Stage 模型开发，可在 DevEco Studio 中直接打开构建安装。

## 功能对照

| 功能 | Python 版 | 鸿蒙版 |
| --- | --- | --- |
| 2/8/10/16 进制输入与实时转换 | ✅ | ✅ |
| `0x` / `0b` / `0o` 前缀自动识别进制 | ✅ | ✅ |
| 位大小 8 ~ 1024（2 的整数次幂） | ✅ | ✅ |
| 16/32/64 位字节序转换（更大位宽按 4 字节单元内反转） | ✅ | ✅ |
| 表达式计算 `+ - * / & \| ^ << >> ()` | ✅ | ✅ |
| 科学计算模式（浮点除法、`^` 次方） | ✅ | ✅ |
| 移位、按位取反、结果按位宽截断 | ✅ | ✅ |
| 位可视化：点选、拖动连选、双击翻转、多选、反转选择位 | ✅ | ✅ |
| 数学表达式中的浮点数/科学计数法 | ✅ | ✅ |
| 历史记录（100 条） | 文件持久化 | 内存 |
| 位显示大小 / 字体大小自定义 | ✅ | ✅（格宽 / 字体滑块） |
| 输入数值超位宽自动回绕 | ✅ | ✅ |

> 说明：JS `number` 仅能精确表示 2⁵³ 以内整数，因此整数运算统一使用 `bigint` 实现，65536 位以内的计算精度与 Python 保持一致。

## 目录结构

```
harmonyos/
├── AppScope/                     # 应用级配置与图标
├── entry/
│   ├── build-profile.json5       # 模块级构建配置(Stage 模型)
│   └── src/main/
│       ├── module.json5          # 模块配置(Ability、权限、页面)
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets   # 入口 Ability
│       │   ├── common/BitwiseCore.ets          # 计算核心 + 表达式解析器(移植自 Python)
│       │   └── pages/Index.ets                 # 主界面
│       └── resources/            # 字符串/颜色/图标等资源
├── test/                         # 本地计算逻辑测试脚手架（无需 DevEco/真机）
│   ├── run.sh                    # 一键：同步核心 + 安装依赖 + 编译 + 跑测试
│   └── src/test.ts               # 52 项单元用例（含与 Python 版对拍的用例）
├── build-profile.json5           # 工程级构建配置
├── hvigorfile.ts
└── oh-package.json5
```

## 构建与运行

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)（推荐 3.1+，API 9 及以上）。
2. DevEco Studio → `File > Open`，选择本 `harmonyos` 目录。
3. 首次打开会自动同步工程配置，必要时按提示升级 / 配置签名（`File > Project Structure > Signing Configs`，登录华为账号自动签名即可）。
4. 连接真机（或使用模拟器）后 `Run` 运行，或 `Build > Build Hap(s)/APP(s)` 生成安装包。

## 本地调试（不依赖 DevEco / 真机）

UI 只能在 DevEco Studio + 真机/模拟器上运行调试，但**计算核心可以在任意装有 Node.js 的机器上单测**：
`BitwiseCore.ets` 是纯逻辑代码（无 ArkUI 依赖），脚手架会把它直接交给 tsc 编译后在 Node 中跑 52 项用例。

```bash
cd harmonyos/test
bash run.sh          # 自动同步 BitwiseCore.ets → src/BitwiseCore.ts 并运行
# 或手动:
npm install
npm test             # 前提：已同步过 BitwiseCore.ets
```

修改 `entry/src/main/ets/common/BitwiseCore.ets` 后，重跑 `run.sh` 即验证新逻辑；生成产物（`src/BitwiseCore.ts`、`out/`、`node_modules/`）不入库。

## 版本兼容

工程默认 `compileSdkVersion / compatibleSdkVersion = 9`（Stage 模型，`@ohos.*` 导入方式）。
如需适配更高 API：开发中可直接在 DevEco Studio 中右键 `Sync`，或手动修改：

- 顶层 `build-profile.json5` 的 `products[].compileSdkVersion / compatibleSdkVersion`
- API 12+ 可将 `EntryAbility.ets` 的 `@ohos.app.ability.*` / `@ohos.window` 导入换成 `@kit.AbilityKit` 等 kit 导入

## 计算规则（与 Python 版一致）

- 普通模式：`/` 为整数向下取整除法，结果按当前位宽截断（负数补码回绕）；`^` 为按位异或。
- 科学计算模式：`/` 为浮点除法，`^` 为次方，结果不做位宽截断。
- 浮点结果显示自动清理 `0.1 + 0.2 = 0.30000000000000004` 这类浮点误差。
- 端序转换：16/32/64 位整字节反转；更大位宽每个 4 字节单元内反转、单元顺序不变。