// 位计算器核心逻辑（由 Python 版 bitwise_calculator.py 移植）
// 说明：JS number 仅能精确表示 2^53 以内整数，位运算必须使用 bigint，
//       因此所有整数计算统一走 bigint，仅科学计算模式下的小数使用 number。

export class CalcValue {
  isDouble: boolean = false;
  intV: bigint = 0n;
  floatV: number = 0;

  static fromInt(v: bigint): CalcValue {
    const c = new CalcValue();
    c.isDouble = false;
    c.intV = v;
    return c;
  }

  static fromFloat(v: number): CalcValue {
    const c = new CalcValue();
    c.isDouble = true;
    c.floatV = v;
    return c;
  }

  isZero(): boolean {
    if (this.isDouble) {
      return this.floatV === 0;
    }
    return this.intV === 0n;
  }

  // 取整数部分（浮点会先截断）
  toInt(): bigint {
    if (this.isDouble) {
      return BigInt(Math.trunc(this.floatV));
    }
    return this.intV;
  }

  toNumber(): number {
    if (this.isDouble) {
      return this.floatV;
    }
    return Number(this.intV);
  }

  neg(): CalcValue {
    if (this.isDouble) {
      return CalcValue.fromFloat(-this.floatV);
    }
    return CalcValue.fromInt(-this.intV);
  }

  add(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      return CalcValue.fromFloat(this.toNumber() + o.toNumber());
    }
    return CalcValue.fromInt(this.intV + o.intV);
  }

  sub(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      return CalcValue.fromFloat(this.toNumber() - o.toNumber());
    }
    return CalcValue.fromInt(this.intV - o.intV);
  }

  mul(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      return CalcValue.fromFloat(this.toNumber() * o.toNumber());
    }
    return CalcValue.fromInt(this.intV * o.intV);
  }

  // floorDiv 为 true 表示普通模式整数(向下取整)除法；false 为科学计算浮点除法
  div(o: CalcValue, floorDiv: boolean): CalcValue {
    if (!floorDiv) {
      if (o.isZero()) {
        throw new Error('除零错误');
      }
      return CalcValue.fromFloat(this.toNumber() / o.toNumber());
    }
    const a = this.toInt();
    const b = o.toInt();
    if (b === 0n) {
      throw new Error('除零错误');
    }
    // bigint 的 / 是向零取整，Python 的 // 是向下取整，这里补正
    let q: bigint = a / b;
    const r: bigint = a % b;
    if (r !== 0n && ((a < 0n) !== (b < 0n))) {
      q = q - 1n;
    }
    return CalcValue.fromInt(q);
  }

  // 次方：与 Python 一致，两个整数且指数非负时保持整数精确计算
  pow(o: CalcValue): CalcValue {
    if (!this.isDouble && !o.isDouble && o.intV >= 0n) {
      if (o.intV > 100000n) {
        throw new Error('指数过大');
      }
      return CalcValue.fromInt(CalcValue.powBig(this.intV, o.intV));
    }
    return CalcValue.fromFloat(Math.pow(this.toNumber(), o.toNumber()));
  }

  private static powBig(base: bigint, exp: bigint): bigint {
    let result: bigint = 1n;
    let b: bigint = base;
    let e: bigint = exp;
    while (e > 0n) {
      if ((e & 1n) !== 0n) {
        result = result * b;
      }
      e = e >> 1n;
      b = b * b;
    }
    return result;
  }

  bitAnd(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      throw new Error('不支持浮点数参与按位与');
    }
    return CalcValue.fromInt(this.intV & o.intV);
  }

  bitOr(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      throw new Error('不支持浮点数参与按位或');
    }
    return CalcValue.fromInt(this.intV | o.intV);
  }

  bitXor(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      throw new Error('不支持浮点数参与按位异或');
    }
    return CalcValue.fromInt(this.intV ^ o.intV);
  }

  shl(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      throw new Error('不支持浮点数参与移位');
    }
    const n = o.intV;
    if (n >= 0n) {
      return CalcValue.fromInt(this.intV << n);
    }
    return CalcValue.fromInt(this.intV >> (-n));
  }

  shr(o: CalcValue): CalcValue {
    if (this.isDouble || o.isDouble) {
      throw new Error('不支持浮点数参与移位');
    }
    const n = o.intV;
    if (n >= 0n) {
      return CalcValue.fromInt(this.intV >> n);
    }
    return CalcValue.fromInt(this.intV << (-n));
  }
}

interface PToken {
  kind: string;
  value: string;
}

class ParserCtx {
  tokens: PToken[] = [];
  i: number = 0;
  scientific: boolean = false;
}

// 表达式解析器：支持 + - * / & | ^ << >> () 以及 0x/0b/0o/0d 前缀、科学计数法
export class ExpressionParser {
  static evaluate(expr: string, scientific: boolean): CalcValue {
    const tokens = ExpressionParser.tokenize(expr);
    const ctx = new ParserCtx();
    ctx.tokens = tokens;
    ctx.scientific = scientific;
    ctx.i = 0;
    const v = ExpressionParser.parseExpression(ctx);
    if (ctx.i < ctx.tokens.length) {
      throw new Error('表达式存在多余内容');
    }
    return v;
  }

  private static tokenize(expr: string): PToken[] {
    const out: PToken[] = [];
    const len = expr.length;
    let i = 0;
    const isDigit = (c: string): boolean => {
      return c >= '0' && c <= '9';
    };
    const isHexLetter = (c: string): boolean => {
      return (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
    };

    while (i < len) {
      const ch: string = expr[i];
      if (ch === ' ' || ch === '\t') {
        i++;
        continue;
      }
      const prev: string = i === 0 ? '' : expr[i - 1];

      // 数字开始：数字、小数点、或十六进制字母（只能出现在开头/0x 之后）
      if (isDigit(ch) || ch === '.' || (isHexLetter(ch) && (i === 0 || prev.toLowerCase() === 'x'))) {
        const start = i;
        let numBase = 0; // 0=十进制 16=十六进制 2=二进制 10=0d 十进制
        if (isHexLetter(ch) && i === 0) {
          // 以十六进制字母开头的裸十六进制数，如 FF
          numBase = 16;
          i += 1;
        } else if (ch === '0' && i + 1 < len) {
          const nxt: string = expr[i + 1].toLowerCase();
          if (nxt === 'x') {
            numBase = 16;
            i += 2;
          } else if (nxt === 'b') {
            numBase = 2;
            i += 2;
          } else if (nxt === 'd') {
            numBase = 10;
            i += 2;
          } else {
            i += 1;
          }
        } else {
          i += 1;
        }
        while (i < len) {
          const nc: string = expr[i];
          const ncl: string = nc.toLowerCase();
          if (isDigit(nc) || nc === '_' ||
            (numBase === 16 && isHexLetter(nc)) ||
            (numBase === 2 && (nc === '0' || nc === '1'))) {
            i++;
          } else if (numBase !== 16 && numBase !== 2 && ncl === 'e') {
            // 科学计数法 1e3 / 1.5e-2 / 2E+10
            let j = i + 1;
            if (j < len && (expr[j] === '+' || expr[j] === '-')) {
              j++;
            }
            if (j < len && (isDigit(expr[j]) || expr[j] === '_')) {
              i = j + 1;
            } else {
              break;
            }
          } else if (numBase !== 2 && nc === '.') {
            i++;
          } else {
            break;
          }
        }
        out.push({ kind: 'NUMBER', value: expr.substring(start, i).replace(/_/g, '') });
        continue;
      }

      // 运算符
      if (ch === '+' || ch === '-' || ch === '*' || ch === '/' || ch === '&' ||
        ch === '|' || ch === '^' || ch === '(' || ch === ')' || ch === '<' || ch === '>') {
        if (ch === '<' && i + 1 < len && expr[i + 1] === '<') {
          out.push({ kind: 'OPERATOR', value: '<<' });
          i += 2;
        } else if (ch === '>' && i + 1 < len && expr[i + 1] === '>') {
          out.push({ kind: 'OPERATOR', value: '>>' });
          i += 2;
        } else {
          out.push({ kind: 'OPERATOR', value: ch });
          i += 1;
        }
        continue;
      }

      // 无前缀的十六进制字母串，如 FF、ABCD
      if (isHexLetter(ch)) {
        const start = i;
        i++;
        while (i < len && (isDigit(expr[i]) || expr[i] === '_' || isHexLetter(expr[i]))) {
          i++;
        }
        out.push({ kind: 'NUMBER', value: expr.substring(start, i).replace(/_/g, '') });
        continue;
      }

      throw new Error('表达式中存在非法字符: ' + ch);
    }
    return out;
  }

  private static parseExpression(ctx: ParserCtx): CalcValue {
    let left: CalcValue = ExpressionParser.parseTerm(ctx);
    while (ctx.i < ctx.tokens.length) {
      const t: PToken = ctx.tokens[ctx.i];
      if (t.kind === 'OPERATOR' && (t.value === '+' || t.value === '-')) {
        ctx.i++;
        const right: CalcValue = ExpressionParser.parseTerm(ctx);
        if (t.value === '+') {
          left = left.add(right);
        } else {
          left = left.sub(right);
        }
      } else {
        break;
      }
    }
    return left;
  }

  private static parseTerm(ctx: ParserCtx): CalcValue {
    let left: CalcValue = ExpressionParser.parseFactor(ctx);
    while (ctx.i < ctx.tokens.length) {
      const t: PToken = ctx.tokens[ctx.i];
      if (t.kind === 'OPERATOR' && (t.value === '*' || t.value === '/')) {
        ctx.i++;
        const right: CalcValue = ExpressionParser.parseFactor(ctx);
        if (t.value === '*') {
          left = left.mul(right);
        } else {
          // 普通模式整数除法，科学计算模式浮点除法
          left = left.div(right, !ctx.scientific);
        }
      } else {
        break;
      }
    }
    return left;
  }

  private static parseFactor(ctx: ParserCtx): CalcValue {
    // 一元运算符 + -
    if (ctx.i < ctx.tokens.length && ctx.tokens[ctx.i].kind === 'OPERATOR' &&
      (ctx.tokens[ctx.i].value === '+' || ctx.tokens[ctx.i].value === '-')) {
      const op: string = ctx.tokens[ctx.i].value;
      ctx.i++;
      const operand: CalcValue = ExpressionParser.parseFactor(ctx);
      return op === '-' ? operand.neg() : operand;
    }

    let left: CalcValue = ExpressionParser.parseAtom(ctx);
    while (ctx.i < ctx.tokens.length) {
      const t: PToken = ctx.tokens[ctx.i];
      if (t.kind !== 'OPERATOR') {
        break;
      }
      const op: string = t.value;
      if (op === '&' || op === '|' || op === '^' || op === '<<' || op === '>>') {
        ctx.i++;
        const right: CalcValue = ExpressionParser.parseAtom(ctx);
        if (op === '&') {
          left = left.bitAnd(right);
        } else if (op === '|') {
          left = left.bitOr(right);
        } else if (op === '^') {
          // 科学计算模式下 ^ 为次方，普通模式下为按位异或
          if (ctx.scientific) {
            left = left.pow(right);
          } else {
            left = left.bitXor(right);
          }
        } else if (op === '<<') {
          left = left.shl(right);
        } else {
          left = left.shr(right);
        }
      } else {
        break;
      }
    }
    return left;
  }

  private static parseAtom(ctx: ParserCtx): CalcValue {
    if (ctx.i >= ctx.tokens.length) {
      throw new Error('表达式不完整');
    }
    const token: PToken = ctx.tokens[ctx.i];
    ctx.i++;
    if (token.kind === 'NUMBER') {
      return ExpressionParser.parseNumberToken(token.value);
    }
    if (token.kind === 'OPERATOR' && token.value === '(') {
      const inside: CalcValue = ExpressionParser.parseExpression(ctx);
      if (ctx.i >= ctx.tokens.length || ctx.tokens[ctx.i].value !== ')') {
        throw new Error('缺少右括号');
      }
      ctx.i++;
      return inside;
    }
    throw new Error('意外的符号: ' + token.value);
  }

  // 解析单个数字 token，返回 CalcValue
  private static parseNumberToken(value: string): CalcValue {
    const lower = value.toLowerCase();
    if (lower === '0b' || lower === '0x' || lower === '0o' || lower === '0d') {
      return CalcValue.fromInt(0n);
    }
    if (lower.startsWith('0x') || lower.startsWith('0b') || lower.startsWith('0o')) {
      try {
        return CalcValue.fromInt(BigInt(lower));
      } catch (e) {
        return CalcValue.fromInt(0n);
      }
    }
    if (lower.startsWith('0d')) {
      const tail = lower.substring(2);
      try {
        return CalcValue.fromInt(BigInt(tail));
      } catch (e) {
        const n = Number(tail);
        if (Number.isNaN(n)) {
          return CalcValue.fromInt(0n);
        }
        return CalcValue.fromFloat(n);
      }
    }
    // 十进制 / 科学计数法
    if (lower.indexOf('.') < 0 && lower.indexOf('e') < 0) {
      try {
        return CalcValue.fromInt(BigInt(lower));
      } catch (e) {
        // 非十进制数字串，可能是无前缀十六进制，如 FF
      }
    }
    const n = Number(lower);
    if (Number.isNaN(n)) {
      try {
        return CalcValue.fromInt(BigInt('0x' + lower));
      } catch (e2) {
        throw new Error('无效数字: ' + value);
      }
    }
    if (Number.isInteger(n) && lower.indexOf('e') < 0 && lower.indexOf('.') < 0) {
      return CalcValue.fromInt(BigInt(Math.trunc(n)));
    }
    return CalcValue.fromFloat(n);
  }
}

// 无状态的计算工具集合
export class BitwiseCore {
  static readonly STD_SIZES: number[] = [8, 16, 32, 64, 128, 256, 512, 1024];
  static readonly MAX_HISTORY: number = 100;

  // 判断字符串是否包含运算符
  static hasOperator(expr: string): boolean {
    return expr.indexOf('+') >= 0 || expr.indexOf('-') >= 0 || expr.indexOf('*') >= 0 ||
      expr.indexOf('/') >= 0 || expr.indexOf('&') >= 0 || expr.indexOf('|') >= 0 ||
      expr.indexOf('^') >= 0 || expr.indexOf('<') >= 0 || expr.indexOf('>') >= 0;
  }

  // 自动识别进制前缀，未识别返回 -1
  static detectBase(valueStr: string): number {
    const lower = valueStr.replace(/_/g, '').toLowerCase().trim();
    if (lower.startsWith('0x')) {
      return 16;
    }
    if (lower.startsWith('0b')) {
      return 2;
    }
    if (lower.startsWith('0o')) {
      return 8;
    }
    return -1;
  }

  // 解析输入字符串为数值（对应 Python 的 get_current_value）
  static parseInput(valueStr: string, base: number): CalcValue {
    let s = valueStr.trim();
    if (s === '') {
      return CalcValue.fromInt(0n);
    }
    let clean = s.replace(/_/g, '');
    const lower = clean.toLowerCase();
    let useBase = base;
    let negative = false;
    if (lower.startsWith('-0x') || lower.startsWith('-0b') || lower.startsWith('-0o')) {
      // 带符号的进制前缀，如 -0xFF，先剥离符号与前缀再按对应进制解析
      negative = true;
      if (lower.startsWith('-0x')) {
        useBase = 16;
      } else if (lower.startsWith('-0b')) {
        useBase = 2;
      } else {
        useBase = 8;
      }
      clean = clean.substring(3);
    } else if (lower.startsWith('0x')) {
      useBase = 16;
      clean = clean.substring(2);
    } else if (lower.startsWith('0b')) {
      useBase = 2;
      clean = clean.substring(2);
    } else if (lower.startsWith('0o')) {
      useBase = 8;
      clean = clean.substring(2);
    }
    if (clean === '') {
      return CalcValue.fromInt(0n);
    }
    if (clean === '-') {
      return CalcValue.fromInt(0n);
    }
    if (negative) {
      try {
        return CalcValue.fromInt(-BitwiseCore.parseIntString(clean, useBase));
      } catch (e) {
        // 与 Python 一致：负数带前缀解析失败时回退为 0
        return CalcValue.fromInt(0n);
      }
    }
    try {
      return CalcValue.fromInt(BitwiseCore.parseIntString(clean, useBase));
    } catch (e) {
      // 整数解析失败则回退为浮点数（与 Python 行为一致）
      return BitwiseCore.parseDecimalString(clean);
    }
  }

  private static parseIntString(s: string, base: number): bigint {
    if (base === 10) {
      return BigInt(s);
    }
    if (base === 16) {
      return BigInt('0x' + s);
    }
    if (base === 8) {
      return BigInt('0o' + s);
    }
    if (base === 2) {
      return BigInt('0b' + s);
    }
    return BigInt(s);
  }

  private static parseDecimalString(s: string): CalcValue {
    if (s.indexOf('.') < 0 && s.indexOf('e') < 0 && s.indexOf('E') < 0) {
      try {
        return CalcValue.fromInt(BigInt(s));
      } catch (e) {
        // continue
      }
    }
    const n = Number(s);
    if (Number.isNaN(n)) {
      return CalcValue.fromInt(0n);
    }
    if (Number.isInteger(n) && s.indexOf('e') < 0 && s.indexOf('E') < 0 && s.indexOf('.') < 0) {
      return CalcValue.fromInt(BigInt(Math.trunc(n)));
    }
    return CalcValue.fromFloat(n);
  }

  // 输入时的位宽截断（普通模式下超界自动回绕，科学计算模式不截断）
  static truncateInput(cv: CalcValue, bitSize: number, scientific: boolean): CalcValue {
    if (scientific) {
      return cv;
    }
    const mask = (1n << BigInt(bitSize)) - 1n;
    if (cv.isDouble) {
      if (cv.intV > mask || cv.intV < 0n) {
        return CalcValue.fromInt(cv.toInt() & mask);
      }
      return cv;
    }
    if (cv.intV > mask || cv.intV < 0n) {
      return CalcValue.fromInt(cv.intV & mask);
    }
    return cv;
  }

  // 计算结果截断（对应 Python 的 calculate：负数补码回绕，浮点结果不截断）
  static truncateResult(cv: CalcValue, bitSize: number, scientific: boolean): CalcValue {
    if (scientific) {
      return cv;
    }
    if (cv.isDouble) {
      return cv;
    }
    const mask = (1n << BigInt(bitSize)) - 1n;
    if (cv.intV > mask || cv.intV < 0n) {
      return CalcValue.fromInt(cv.intV & mask);
    }
    return cv;
  }

  // 按位宽回绕为无符号数
  static toUnsigned(v: bigint, bitSize: number): bigint {
    const mask = (1n << BigInt(bitSize)) - 1n;
    return v & mask;
  }

  // 格式化当前值文本（带进制前缀，对应 Python format_number）
  static formatText(cv: CalcValue, base: number): string {
    if (cv.isDouble) {
      if (Number.isInteger(cv.floatV)) {
        return String(Math.trunc(cv.floatV));
      }
      return BitwiseCore.formatFloat(cv.floatV);
    }
    return BitwiseCore.formatInt(cv.intV, base);
  }

  static formatInt(v: bigint, base: number): string {
    switch (base) {
      case 2:
        return BitwiseCore.withPrefix(v, '0b', 2, false);
      case 8:
        return BitwiseCore.withPrefix(v, '0o', 8, false);
      case 16: {
        if (v < 0n) {
          return '-0x' + v.toString(16).substring(1).toUpperCase();
        }
        return '0x' + v.toString(16).toUpperCase();
      }
      default:
        return v.toString();
    }
  }

  private static withPrefix(v: bigint, prefix: string, radix: number, upper: boolean): string {
    const s: string = v.toString(radix);
    if (v < 0n) {
      return '-' + prefix + (upper ? s.substring(1).toUpperCase() : s.substring(1));
    }
    return prefix + (upper ? s.toUpperCase() : s);
  }

  // 浮点数格式化，消除 0.1+0.2=0.30000000000000004 之类的浮点误差
  static formatFloat(value: number): string {
    let rounded = BitwiseCore.roundDec(value, 15);
    for (let i = 15; i >= 1; i--) {
      const t = BitwiseCore.roundDec(value, i);
      if (Math.abs(t - value) < 1e-10) {
        rounded = t;
        break;
      }
    }
    let s = String(rounded);
    if (s.indexOf('.') >= 0) {
      while (s.length > 0 && s.charAt(s.length - 1) === '0') {
        s = s.substring(0, s.length - 1);
      }
      if (s.length > 0 && s.charAt(s.length - 1) === '.') {
        s = s.substring(0, s.length - 1);
      }
    }
    return s;
  }

  private static roundDec(value: number, decimals: number): number {
    return Number(value.toFixed(decimals));
  }

  // 结果展示（无前缀；负数按符号-数值形式展示）
  static binText(cv: CalcValue): string {
    return cv.toInt().toString(2);
  }

  static octText(cv: CalcValue): string {
    return cv.toInt().toString(8);
  }

  static decText(cv: CalcValue): string {
    if (cv.isDouble) {
      return BitwiseCore.formatFloat(cv.floatV);
    }
    return cv.toInt().toString(10);
  }

  static hexText(cv: CalcValue): string {
    return cv.toInt().toString(16).toUpperCase();
  }

  // 生成位显示字符串（MSB 在前，不足位宽补 0）
  static bitsString(cv: CalcValue, bitSize: number): string {
    const unsigned = BitwiseCore.toUnsigned(cv.toInt(), bitSize);
    return unsigned.toString(2).padStart(bitSize, '0');
  }

  // 自动识别所需位宽（向上对齐到 8/16/32/64/... 的 2 的整数次幂）
  static autoDetectBitSize(v: bigint): number {
    if (v === 0n) {
      return 8;
    }
    let bits: number;
    if (v < 0n) {
      bits = (-v).toString(2).length + 1;
    } else {
      bits = v.toString(2).length;
    }
    for (let i = 0; i < BitwiseCore.STD_SIZES.length; i++) {
      if (bits <= BitwiseCore.STD_SIZES[i]) {
        return BitwiseCore.STD_SIZES[i];
      }
    }
    return 1024;
  }

  // 端序转换：16/32/64 位整体字节反转；更大位宽按 32 位(4字节)单元内反转，单元顺序保持不变
  static convertEndian(value: bigint, bitSize: number): bigint {
    if (bitSize <= 8) {
      return value;
    }
    if (bitSize === 16) {
      return BitwiseCore.reverseBytes(value, 2, 2);
    }
    if (bitSize === 32) {
      return BitwiseCore.reverseBytes(value, 4, 4);
    }
    if (bitSize === 64) {
      return BitwiseCore.reverseBytes(value, 8, 8);
    }
    return BitwiseCore.reverseBytes(value, Math.floor(bitSize / 8), 4);
  }

  private static reverseBytes(value: bigint, byteCount: number, perGroup: number): bigint {
    let res = 0n;
    for (let b = 0; b < byteCount; b++) {
      const byteNum = (value >> BigInt(b * 8)) & 0xFFn;
      const group = Math.floor(b / perGroup);
      const off = b % perGroup;
      const target = group * perGroup + (perGroup - 1 - off);
      if (byteNum !== 0n) {
        res = res | (byteNum << BigInt(target * 8));
      }
    }
    return res;
  }

  // 计算选中位组合后的值（与 Python 一致：选中位按位置重组）
  static selectedValue(current: bigint, selectedIdx: number[]): bigint {
    let sv = 0n;
    for (let c = 0; c < selectedIdx.length; c++) {
      if (((current >> BigInt(selectedIdx[c])) & 1n) !== 0n) {
        sv = sv | (1n << BigInt(c));
      }
    }
    return sv;
  }
}