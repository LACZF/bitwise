// 计算核心本地单元测试
// 运行方式：
//   bash run.sh          （自动同步 BitwiseCore.ets、安装依赖、编译并运行）
//   npm test             （前提：已同步 src/BitwiseCore.ts 且有 node_modules）
//
// 覆盖：进制解析、表达式计算、科学计算模式、格式化、位宽截断、端序转换、
//       位串生成、选中位组合值。部分断言结果与 Python 版实现逐一对拍。

import { BitwiseCore, CalcValue, ExpressionParser } from './BitwiseCore';

let pass = 0;
let fail = 0;

const str = (v: unknown): string => {
  if (typeof v === 'bigint') {
    return v.toString();
  }
  return JSON.stringify(v);
};

function eq(actual: unknown, expected: unknown, name: string): void {
  if (str(actual) === str(expected)) {
    pass++;
  } else {
    fail++;
    console.log('FAIL', name, '=>', str(actual), 'expected', str(expected));
  }
}

function throws(fn: () => unknown, name: string): void {
  try {
    fn();
    fail++;
    console.log('FAIL', name, '=> expected an error but none thrown');
  } catch (e) {
    pass++;
  }
}

// ---------------- 进制解析 ----------------
eq(BitwiseCore.parseInput('0', 10).toInt() === 0n, true, '零值');
eq(BitwiseCore.parseInput('0xFF', 10).toInt(), 255n, '0xFF 前缀应识别为16进制');
eq(BitwiseCore.parseInput('FF', 16).toInt(), 255n, 'base16 下 FF');
eq(BitwiseCore.parseInput('1011', 2).toInt(), 11n, 'base2 下 1011');
eq(BitwiseCore.parseInput('0b1011', 10).toInt(), 11n, '0b 前缀');
eq(BitwiseCore.parseInput('0o17', 10).toInt(), 15n, '0o 前缀');
eq(BitwiseCore.parseInput('1.5', 10).toNumber(), 1.5, '浮点输入');
eq(BitwiseCore.parseInput('-5', 10).toInt(), -5n, '负数输入');
eq(BitwiseCore.parseInput('12345678901234567890', 10).toInt().toString(),
  '12345678901234567890', '大整数精确(>2^53)');
eq(BitwiseCore.detectBase('0x1A'), 16, '识别 0x');
eq(BitwiseCore.detectBase('0b1'), 2, '识别 0b');
eq(BitwiseCore.detectBase('0o7'), 8, '识别 0o');
eq(BitwiseCore.detectBase('123'), -1, '无前缀返回 -1');

// ---------------- 普通模式表达式 ----------------
eq(ExpressionParser.evaluate('0x1F & 0b1011', false).toInt(), 0x1F & 11, '16进制与二进制按位与');
eq(ExpressionParser.evaluate('1 << 4', false).toInt(), 16n, '左移');
eq(ExpressionParser.evaluate('255 >> 3', false).toInt(), 31n, '右移');
eq(ExpressionParser.evaluate('7 | 8', false).toInt(), 15n, '按位或');
eq(ExpressionParser.evaluate('7 ^ 3', false).toInt(), 4n, '按位异或');
eq(ExpressionParser.evaluate('10 - 4 * 2', false).toInt(), 2n, '乘法优先级');
eq(ExpressionParser.evaluate('(10 - 4) * 2', false).toInt(), 12n, '括号');
eq(ExpressionParser.evaluate('1/2', false).toInt(), 0n, '整数除法 1/2');
eq(ExpressionParser.evaluate('-7/2', false).toInt(), -4n, '负数向下取整除法');
eq(ExpressionParser.evaluate('0b1010 & 0b0110', false).toInt(), 2n, '二进制按位与');
eq(ExpressionParser.evaluate('1 << 100', false).toInt().toString(),
  '1267650600228229401496703205376', '大数移位');
eq(ExpressionParser.evaluate('0b101 << 1', false).toInt(), 10n, '表达式中的 0b');
eq(ExpressionParser.evaluate('FF & 0x0F', false).toInt(), 15n, '表达式中的裸十六进制 FF');

// ---------------- 科学计算模式 ----------------
eq(ExpressionParser.evaluate('10 / 4', true).toNumber(), 2.5, '科学模式浮点除法');
eq(ExpressionParser.evaluate('2^10', true).toNumber(), 1024, '科学模式 ^ 为次方');
eq(ExpressionParser.evaluate('2^3', false).toInt(), 1n, '普通模式 ^ 为异或');
eq(ExpressionParser.evaluate('1.5e2', true).toNumber(), 150, '科学计数法 1.5e2');
eq(ExpressionParser.evaluate('2e3 + 1', true).toNumber(), 2001, '科学计数法加法');
eq(ExpressionParser.evaluate('-0.5', true).toNumber(), -0.5, '一元负号浮点');
eq(BitwiseCore.formatFloat(0.1 + 0.2), '0.3', '浮点误差清理 0.1+0.2');
eq(BitwiseCore.formatFloat(2.5), '2.5', '浮点格式化 2.5');
throws(() => ExpressionParser.evaluate('1.5 & 1', false), '浮点参与按位与会报错');
throws(() => ExpressionParser.evaluate('1 / 0', false), '除零报错');

// ---------------- 格式化 ----------------
eq(BitwiseCore.formatText(CalcValue.fromInt(11n), 2), '0b1011', '格式化二进制');
eq(BitwiseCore.formatText(CalcValue.fromInt(11n), 8), '0o13', '格式化八进制');
eq(BitwiseCore.formatText(CalcValue.fromInt(11n), 10), '11', '格式化十进制');
eq(BitwiseCore.formatText(CalcValue.fromInt(11n), 16), '0xB', '格式化十六进制(大写)');

// ---------------- 位宽截断 ----------------
eq(BitwiseCore.truncateResult(CalcValue.fromInt(123456789n), 32, false).toInt(),
  123456789n & 0xFFFFFFFFn, '超位宽截断');
eq(BitwiseCore.truncateResult(CalcValue.fromInt(-1n), 8, false).toInt(), 255n, '负数补码回绕');
eq(BitwiseCore.truncateResult(CalcValue.fromInt(256n), 8, false).toInt(), 0n, '溢出回绕(256->8位)');
eq(BitwiseCore.truncateResult(CalcValue.fromFloat(2.5), 8, false).isDouble, true, '浮点结果不截断');

// ---------------- 移位按位宽截断 ----------------
const p = 0xFFFFFFFFn;
const mask32 = (1n << 32n) - 1n;
eq((p << 8n) & mask32, 0xFFFFFF00n, '64位值左移后按32位截断');

// ---------------- 端序转换（与 Python 版对拍） ----------------
eq(BitwiseCore.convertEndian(0x1234n, 16), 0x3412n, '16位端序转换');
eq(BitwiseCore.convertEndian(0x12345678n, 32), 0x78563412n, '32位端序转换');
eq(BitwiseCore.convertEndian(0x1122334455667788n, 64), 0x8877665544332211n, '64位端序转换');
// 128 位：两个 32 位单元各自反转、单元顺序不变（Python 期望 0x01000000020000000300000004000000）
eq(BitwiseCore.convertEndian(0x00000001_00000002_00000003_00000004n, 128),
  0x01000000020000000300000004000000n, '128位端序转换');

// ---------------- 位串生成 ----------------
eq(BitwiseCore.bitsString(CalcValue.fromInt(5n), 8), '00000101', '位串(MSB在前)');
eq(BitwiseCore.bitsString(CalcValue.fromInt(-1n), 8), '11111111', '负数补码位串');

// ---------------- 选中位组合值 ----------------
eq(BitwiseCore.selectedValue(0b1010n, [1, 3]), 0b11n, '选中位重组值');

// ---------------- 汇总 ----------------
console.log(`通过 ${pass} 项, 失败 ${fail} 项`);
if (fail > 0) {
  throw new Error('存在失败的测试用例');
}
console.log('全部通过 ✔');