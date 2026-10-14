import { BitwiseCore, CalcValue, ExpressionParser } from '../common/BitwiseCore';
import window from '@ohos.window';
import { BusinessError } from '@ohos.base';
import { LengthMetrics } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';

const COL_BIT_1: string = '#90EE90';
const COL_BIT_0: string = '#F08080';
const COL_SEL_1: string = '#ADD8E6';
const COL_SEL_0: string = '#FFFFE0';

const PREF_FILE: string = 'bitwise_history';
const KEY_HISTORY: string = 'history';

@Extend(Column) function cardStyle() {
  .backgroundColor('#FFFFFF')
  .borderRadius(10)
  .padding(12)
  .width('100%')
  .alignItems(HorizontalAlign.Start)
}

interface BitCell {
  bitIdx: number;
  key: string;
}

interface ResultRowParam {
  label: string;
  value: string;
}

@CustomDialog
struct AboutDialog {
  controller?: CustomDialogController;

  build() {
    Column({ space: 10 }) {
      Text('关于 Bitwise')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('程序员位运算/进制转换计算器（由 Python 版 bitwise_calculator 移植）。')
        .fontSize(14)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('功能：')
        .fontSize(14)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('- 2/8/10/16 进制输入与实时转换（支持 0x/0b/0o 前缀自动识别）\n' +
        '- 位大小 8~1024，16/32/64 位端序转换\n' +
        '- 表达式计算：+ - * / & | ^ << >> ()\n' +
        '- 移位、按位取反、科学计算模式（浮点除法、^ 次方）\n' +
        '- 位可视化：单击选择、拖动连选、双击翻转、多选 + 反转')
        .fontSize(14)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Start)
      Text('GitHub: https://github.com/LACZF/bitwise')
        .fontSize(14)
        .fontColor('#1F6FEB')
        .width('100%')
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.LocalDevice)
      Button('知道了')
        .fontSize(13)
        .height(30)
        .padding({ left: 18, right: 18 })
        .margin({ top: 8 })
        .alignSelf(ItemAlign.Center)
        .onClick(() => {
          if (this.controller) {
            this.controller.close();
          }
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}

@Entry
@Component
struct Index {
  @State currentValue: string = '0';
  @State resultText: string = '0';
  @State base: number = 10;
  @State bitSize: number = 64;
  @State littleEndian: boolean = true;
  @State scientific: boolean = false;
  @State windowTopmost: boolean = false;

  @State cellSize: number = 25;
  @State autoFit: boolean = true;
  @State fontSize: number = 14;
  @State shiftAmount: string = '1';

  @State selectedBits: number[] = [];
  @State history: string[] = [];
  @State multiSelect: boolean = false;
  @State errorMsg: string = '';

  @State binText: string = '0';
  @State octText: string = '0';
  @State decText: string = '0';
  @State hexText: string = '0';
  @State bitStr: string = '';

  @State selInfo: string = '位选择结果：未选择任何位';
  @State selBin: string = '';
  @State selOct: string = '';
  @State selDec: string = '';
  @State selHex: string = '';

  private parsedInt: bigint = 0n;
  private workCalc: CalcValue = CalcValue.fromInt(0n);
  private prefs: preferences.Preferences | null = null;
  private gridWidth: number = 0;
  private isDragging: boolean = false;
  private dragAnchor: number = -1;
  private lastTapIdx: number = -1;
  private lastTapTime: number = 0;

  private aboutDialogController: CustomDialogController = new CustomDialogController({
    builder: AboutDialog(),
    autoCancel: true
  });

  aboutToAppear(): void {
    this.loadHistory();
    this.syncFromInput();
  }

  onPageShow(): void {
    this.loadHistory();
  }

  // ------------------------- 输入与显示 -------------------------

  onInputChange(v: string): void {
    this.currentValue = v;
    this.syncFromInput();
  }

  syncFromInput(): void {
    const det = BitwiseCore.detectBase(this.currentValue);
    if (det > 0) {
      this.base = det;
    }
    let cv = BitwiseCore.parseInput(this.currentValue, this.base);
    cv = BitwiseCore.truncateInput(cv, this.bitSize, this.scientific);
    this.workCalc = cv;
    this.refreshDisplays();
  }

  applyResult(cv: CalcValue): void {
    this.workCalc = BitwiseCore.truncateInput(cv, this.bitSize, this.scientific);
    this.resultText = BitwiseCore.formatText(this.workCalc, this.base);
    this.errorMsg = '';
    // 与 Python 版一致：计算后将输入框同步为结果，避免输入框残留表达式，
    // 导致后续 syncFromInput 重新解析失败而使位显示回退为 0
    this.currentValue = this.resultText;
    this.refreshDisplays();
  }

  refreshDisplays(): void {
    const cv = this.workCalc;
    this.parsedInt = cv.toInt();
    const unsigned = BitwiseCore.toUnsigned(this.parsedInt, this.bitSize);
    this.bitStr = unsigned.toString(2).padStart(this.bitSize, '0');
    this.binText = BitwiseCore.binText(cv);
    this.octText = BitwiseCore.octText(cv);
    this.decText = BitwiseCore.decText(cv);
    this.hexText = BitwiseCore.hexText(cv);
    if (this.autoFit) {
      this.autoFitCells();
    }
    this.evalSelection();
  }

  setResultValue(v: bigint): void {
    this.applyResult(CalcValue.fromInt(v));
  }

  doCalculate(): void {
    if (BitwiseCore.hasOperator(this.currentValue)) {
      try {
        const r0 = ExpressionParser.evaluate(this.currentValue, this.scientific);
        const r = BitwiseCore.truncateResult(r0, this.bitSize, this.scientific);
        this.addHistory(this.currentValue);
        this.applyResult(r);
      } catch (e) {
        this.errorMsg = (e as Error).message;
      }
    } else {
      this.syncFromInput();
      this.resultText = BitwiseCore.formatText(this.workCalc, this.base);
      this.errorMsg = '';
    }
  }

  clearAll(): void {
    this.currentValue = '0';
    this.resultText = '0';
    this.errorMsg = '';
    this.syncFromInput();
  }

  shift(dir: string): void {
    const a = parseInt(this.shiftAmount.trim(), 10);
    if (Number.isNaN(a)) {
      this.errorMsg = '移位量无效';
      return;
    }
    const mask = (1n << BigInt(this.bitSize)) - 1n;
    let v = this.parsedInt;
    const amt = BigInt(a >= 0 ? a : -a);
    if (dir === 'left') {
      v = (v << amt) & mask;
    } else {
      v = (v >> amt) & mask;
    }
    this.setResultValue(v);
  }

  bitwiseNot(): void {
    const mask = (1n << BigInt(this.bitSize)) - 1n;
    this.setResultValue((~this.parsedInt) & mask);
  }

  onEndianChange(v: boolean): void {
    if (v === this.littleEndian) {
      return;
    }
    this.littleEndian = v;
    if (this.bitSize > 8) {
      const converted = BitwiseCore.convertEndian(this.parsedInt, this.bitSize);
      this.setResultValue(converted);
    }
  }

  toggleTopmost(isOn: boolean): void {
    this.windowTopmost = isOn;
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      this.errorMsg = '窗口置顶失败：无法获取应用上下文';
      this.windowTopmost = !isOn;
      return;
    }
    window.getLastWindow(ctx)
      .then((win: window.Window) => {
        return win.setWindowTopmost(isOn);
      })
      .then(() => {
        this.errorMsg = '';
      })
      .catch((e: BusinessError) => {
        this.windowTopmost = !isOn;
        this.errorMsg = '窗口置顶失败 (' + e.code + ')：仅支持自由窗口模式（PC/2in1）';
      });
  }

  onBitSizeSelect(index: number): void {
    if (index >= 0 && index < BitwiseCore.STD_SIZES.length) {
      this.bitSize = BitwiseCore.STD_SIZES[index];
      this.workCalc = BitwiseCore.truncateInput(this.workCalc, this.bitSize, this.scientific);
      this.refreshDisplays();
    }
  }

  onBaseChange(b: number): void {
    this.base = b;
    this.syncFromInput();
  }

  addHistory(value: string): void {
    let list: string[] = [];
    list.push(...this.history);
    const idx = list.indexOf(value);
    if (idx >= 0) {
      list.splice(idx, 1);
    }
    list.push(value);
    if (list.length > BitwiseCore.MAX_HISTORY) {
      list = list.slice(list.length - BitwiseCore.MAX_HISTORY);
    }
    this.history = list;
    this.saveHistory();
  }

  loadHistory(): void {
    if (this.prefs !== null) {
      return;
    }
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx === undefined) {
        return;
      }
      this.prefs = preferences.getPreferencesSync(ctx, { name: PREF_FILE });
      const saved = this.prefs.getSync(KEY_HISTORY, '');
      if (typeof saved === 'string' && saved.length > 0) {
        this.history = saved.split('\n');
      }
    } catch (e) {
      this.prefs = null;
    }
  }

  saveHistory(): void {
    if (this.prefs === null) {
      return;
    }
    try {
      this.prefs.putSync(KEY_HISTORY, this.history.join('\n'));
      this.prefs.flush()
        .then(() => {
        })
        .catch((_e: BusinessError) => {
        });
    } catch (e) {
    }
  }

  bitSizeIndex(): number {
    for (let i = 0; i < BitwiseCore.STD_SIZES.length; i++) {
      if (BitwiseCore.STD_SIZES[i] === this.bitSize) {
        return i;
      }
    }
    return 0;
  }

  sizeOptions(): SelectOption[] {
    const opts: SelectOption[] = [];
    for (let i = 0; i < BitwiseCore.STD_SIZES.length; i++) {
      opts.push({ value: BitwiseCore.STD_SIZES[i] + ' 位' });
    }
    return opts;
  }

  historyShown(): string[] {
    return this.history.length > 30 ? this.history.slice(this.history.length - 30) : this.history;
  }

  historyMenuItems(): MenuElement[] {
    const show = this.historyShown();
    const items: MenuElement[] = [];
    if (show.length === 0) {
      items.push({
        value: '（暂无历史）',
        enabled: false,
        action: () => {
        }
      });
    } else {
      for (let i = show.length - 1; i >= 0; i--) {
        const entry: string = show[i];
        items.push({
          value: entry,
          action: () => {
            this.currentValue = entry;
            this.doCalculate();
          }
        });
      }
    }
    return items;
  }

  // ------------------------- 位显示与选择 -------------------------

  getCells(): BitCell[] {
    const list: BitCell[] = [];
    for (let bitIdx = 0; bitIdx < this.bitSize; bitIdx++) {
      list.push({ bitIdx: bitIdx, key: 'b' + bitIdx });
    }
    return list;
  }

  cellPos(bitIdx: number): number {
    return this.bitSize - 1 - bitIdx;
  }

  cellBit(bitIdx: number): string {
    return this.bitStr.charAt(this.cellPos(bitIdx));
  }

  cellColor(bitIdx: number): string {
    const one = this.cellBit(bitIdx) === '1';
    const sel = this.selectedBitsContain(bitIdx);
    return sel ? (one ? COL_SEL_1 : COL_SEL_0) : (one ? COL_BIT_1 : COL_BIT_0);
  }

  cellX(bitIdx: number): number {
    return (this.cellPos(bitIdx) % 32) * this.cellSize;
  }

  cellY(bitIdx: number): number {
    return Math.floor(this.cellPos(bitIdx) / 32) * (this.cellSize + 18);
  }

  selectedBitsContain(idx: number): boolean {
    for (let i = 0; i < this.selectedBits.length; i++) {
      if (this.selectedBits[i] === idx) {
        return true;
      }
    }
    return false;
  }

  gridRows(): number {
    return Math.ceil(this.bitSize / 32);
  }

  gridHeight(): number {
    return this.gridRows() * (this.cellSize + 18);
  }

  cellFromPos(x: number, y: number): number {
    const w = this.cellSize;
    const rh = this.cellSize + 18;
    const col = Math.floor(x / w);
    const row = Math.floor(y / rh);
    if (col < 0 || col > 31) {
      return -1;
    }
    const p = row * 32 + col;
    if (p < 0 || p >= this.bitSize) {
      return -1;
    }
    return this.bitSize - 1 - p;
  }

  onBitDown(idx: number): void {
    this.dragAnchor = idx;
    this.isDragging = true;
    if (this.multiSelect) {
      this.toggleSelection(idx);
    } else {
      this.selectedBits = [idx];
      this.evalSelection();
    }
  }

  onBitMove(idx: number): void {
    if (!this.isDragging || idx < 0) {
      return;
    }
    const start = Math.min(this.dragAnchor, idx);
    const end = Math.max(this.dragAnchor, idx);
    const list: number[] = [];
    for (let b = start; b <= end; b++) {
      list.push(b);
    }
    this.selectedBits = list;
    this.evalSelection();
  }

  onBitUp(): void {
    this.isDragging = false;
  }

  // 单击选择/双击翻转位值（用时间差区分两次点击）
  onBitTap(idx: number): void {
    const now = Date.now();
    if (idx === this.lastTapIdx && (now - this.lastTapTime) < 400) {
      this.lastTapIdx = -1;
      this.toggleBitValue(idx);
      return;
    }
    this.lastTapIdx = idx;
    this.lastTapTime = now;
  }

  toggleBitValue(idx: number): void {
    const mask = 1n << BigInt(idx);
    const newValue = this.parsedInt ^ mask;
    this.selectedBits = [idx];
    this.setResultValue(newValue);
  }

  toggleSelection(idx: number): void {
    const list: number[] = [];
    list.push(...this.selectedBits);
    const pos = list.indexOf(idx);
    if (pos >= 0) {
      list.splice(pos, 1);
    } else {
      list.push(idx);
    }
    this.selectedBits = list;
    this.evalSelection();
  }

  clearSelection(): void {
    this.selectedBits = [];
    this.evalSelection();
  }

  invertSelection(): void {
    if (this.selectedBits.length === 0) {
      return;
    }
    let v = this.parsedInt;
    for (let i = 0; i < this.selectedBits.length; i++) {
      const mask = 1n << BigInt(this.selectedBits[i]);
      v = v ^ mask;
    }
    this.setResultValue(v);
  }

  evalSelection(): void {
    const n = this.selectedBits.length;
    if (n === 0) {
      this.selInfo = '位选择结果：未选择任何位';
      this.selBin = '';
      this.selOct = '';
      this.selDec = '';
      this.selHex = '';
      return;
    }
    const sorted: number[] = [];
    sorted.push(...this.selectedBits);
    sorted.sort((a: number, b: number) => a - b);
    const sv = BitwiseCore.selectedValue(this.parsedInt, sorted);
    let contig = true;
    for (let i = 1; i < sorted.length; i++) {
      if (sorted[i] !== sorted[i - 1] + 1) {
        contig = false;
        break;
      }
    }
    const maxBit = sorted[sorted.length - 1];
    const minBit = sorted[0];
    if (contig) {
      this.selInfo = '位选择结果：选择了位 ' + maxBit + ' 到 ' + minBit + ' (共 ' + n + ' 位)';
    } else {
      this.selInfo = '位选择结果：选择了位: ' + sorted.join(', ') + ' (共 ' + n + ' 位)';
    }
    this.selBin = sv.toString(2).padStart(n, '0');
    this.selOct = sv.toString(8);
    this.selDec = sv.toString(10);
    this.selHex = sv.toString(16).toUpperCase();
  }

  // ------------------------- 显示相关配置 -------------------------

  autoFitCells(): void {
    if (this.gridWidth <= 1) {
      return;
    }
    const cell = Math.max(8, Math.min(60, Math.floor((this.gridWidth - 24) / 32)));
    if (cell !== this.cellSize) {
      this.cellSize = cell;
    }
  }

  onCellSizeInput(v: string): void {
    const n = parseInt(v.trim(), 10);
    if (Number.isNaN(n) || n < 8 || n > 60 || n === this.cellSize) {
      return;
    }
    this.autoFit = false;
    this.cellSize = n;
  }

  onFontSizeInput(v: string): void {
    const n = parseInt(v.trim(), 10);
    if (Number.isNaN(n) || n < 10 || n > 22) {
      return;
    }
    this.fontSize = n;
  }

  showAbout(): void {
    this.aboutDialogController.open();
  }

  // ------------------------- UI 构建 -------------------------

  @Builder
  cardTitle(title: string) {
    Text(title)
      .fontSize(this.fontSize + 2)
      .fontWeight(FontWeight.Bold)
      .fontColor('#333333')
  }

  @Builder
  resultRow(param: ResultRowParam) {
    Row() {
      Text(param.label)
        .fontSize(this.fontSize)
        .fontColor('#666666')
        .width(72)
      Text(param.value)
        .fontSize(this.fontSize)
        .fontColor('#1a1a1a')
        .fontFamily('monospace')
        .maxLines(1)
        .minLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 2, bottom: 2 })
  }

  @Builder
  baseRadio(value: number, label: string) {
    Row({ space: 3 }) {
      Radio({ value: value + '', group: 'baseGroup' })
        .checked(this.base === value)
        .onChange((checked: boolean) => {
          if (checked) {
            this.onBaseChange(value);
          }
        })
      Text(label)
        .fontSize(this.fontSize)
    }
  }

  build() {
    Scroll() {
      Column({ space: 8 }) {
        // ---------- 标题栏 ----------
        Row() {
          Text('位计算器')
            .fontSize(this.fontSize + 6)
            .fontWeight(FontWeight.Bold)
          Blank()
          Button('关于')
            .fontSize(this.fontSize)
            .height(32)
            .onClick(() => this.showAbout())
        }
        .width('100%')

        // ---------- 数值输入 ----------
        Column({ space: 8 }) {
          this.cardTitle('数值输入')
          Stack({ alignContent: Alignment.End }) {
            TextInput({ text: this.currentValue, placeholder: '数值或表达式' })
              .fontSize(this.fontSize)
              .fontFamily('monospace')
              .height(40)
              .width('100%')
              .padding({ right: 32 })
              .onChange((v: string) => this.onInputChange(v))
              .onSubmit(() => this.doCalculate())
            Text('▼')
              .fontSize(12)
              .fontColor('#666666')
              .width(28)
              .height(40)
              .textAlign(TextAlign.Center)
              .bindMenu(this.historyMenuItems(), { placement: Placement.BottomRight, title: '历史记录' })
          }
          .width('100%')

          if (this.errorMsg !== '') {
            Text(this.errorMsg)
              .fontSize(this.fontSize)
              .fontColor('#D32F2F')
              .width('100%')
          }
        }
        .cardStyle()

        // ---------- 操作和进制 ----------
        Column({ space: 8 }) {
          this.cardTitle('操作和进制')
          Row({ space: 4 }) {
            Text('结果:')
              .fontSize(this.fontSize)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
            TextInput({ text: this.resultText })
              .fontSize(this.fontSize)
              .fontFamily('monospace')
              .height(32)
              .layoutWeight(1)
              .padding({ left: 6, right: 6 })
              .enableKeyboardOnFocus(false)
              .copyOption(CopyOptions.LocalDevice)
              .onWillInsert((_value: InsertValue) => false)
              .onWillDelete((_value: DeleteValue) => false)
            Text('移位:')
              .fontSize(this.fontSize)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
            TextInput({ text: this.shiftAmount, placeholder: '1' })
              .fontSize(this.fontSize)
              .width(56)
              .height(32)
              .textAlign(TextAlign.Center)
              .onChange((v: string) => {
                this.shiftAmount = v;
              })
            Button('<<')
              .fontSize(this.fontSize)
              .height(32)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.shift('left'))
            Button('>>')
              .fontSize(this.fontSize)
              .height(32)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.shift('right'))
            Button('=')
              .fontSize(this.fontSize)
              .height(32)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.doCalculate())
            Button('~')
              .fontSize(this.fontSize)
              .height(32)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.bitwiseNot())
            Button('C')
              .fontSize(this.fontSize)
              .height(32)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.clearAll())
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 8 }) {
            Text('输入进制')
              .fontSize(this.fontSize)
            this.baseRadio(2, '2进制')
            this.baseRadio(8, '8进制')
            this.baseRadio(10, '10进制')
            this.baseRadio(16, '16进制')
            Text('位大小')
              .fontSize(this.fontSize)
            Select(this.sizeOptions())
              .selected(this.bitSizeIndex())
              .value(this.bitSize + ' 位')
              .width(100)
              .onSelect((index: number) => this.onBitSizeSelect(index))
            Text('字节序')
              .fontSize(this.fontSize)
            Radio({ value: 'little', group: 'endianGroup' })
              .checked(this.littleEndian)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.onEndianChange(true);
                }
              })
            Text('小端序')
              .fontSize(this.fontSize)
            Radio({ value: 'big', group: 'endianGroup' })
              .checked(!this.littleEndian)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.onEndianChange(false);
                }
              })
            Text('大端序')
              .fontSize(this.fontSize)
            Toggle({ type: ToggleType.Switch, isOn: this.scientific })
              .onChange((isOn: boolean) => {
                this.scientific = isOn;
                this.workCalc = BitwiseCore.truncateInput(this.workCalc, this.bitSize, this.scientific);
                this.refreshDisplays();
              })
            Text('科学计算')
              .fontSize(this.fontSize)
            Toggle({ type: ToggleType.Switch, isOn: this.windowTopmost })
              .onChange((isOn: boolean) => {
                this.toggleTopmost(isOn);
              })
            Text('窗口置顶')
              .fontSize(this.fontSize)
          }
          .width('100%')
        }
        .cardStyle()

        // ---------- 进制转换结果 与 位选择结果 ----------
        Flex({
          direction: FlexDirection.Row,
          alignItems: ItemAlign.Stretch,
          space: { main: LengthMetrics.vp(8) }
        }) {
          Column({ space: 4 }) {
            this.cardTitle('进制转换结果')
            this.resultRow({ label: '二进制:', value: this.binText })
            this.resultRow({ label: '八进制:', value: this.octText })
            this.resultRow({ label: '十进制:', value: this.decText })
            this.resultRow({ label: '十六进制:', value: this.hexText })
          }
          .cardStyle()
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(this.selInfo)
              .fontSize(this.fontSize + 1)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
              .minLines(2)
              .maxLines(2)
            this.resultRow({ label: '二进制:', value: this.selBin })
            this.resultRow({ label: '八进制:', value: this.selOct })
            this.resultRow({ label: '十进制:', value: this.selDec })
            this.resultRow({ label: '十六进制:', value: this.selHex })
            Row({ space: 8 }) {
              Button('清除选择')
                .fontSize(Math.max(10, this.fontSize - 2))
                .height(28)
                .padding({ left: 8, right: 8 })
                .onClick(() => this.clearSelection())
              Button('反转选择位')
                .fontSize(Math.max(10, this.fontSize - 2))
                .height(28)
                .padding({ left: 8, right: 8 })
                .onClick(() => this.invertSelection())
            }
            .width('100%')
          }
          .cardStyle()
          .layoutWeight(1)
        }
        .width('100%')

        // ---------- 位显示 ----------
        Column({ space: 8 }) {
          this.cardTitle('位显示')
          Row({ space: 10 }) {
            Text('格宽')
              .fontSize(this.fontSize)
            TextInput({ text: this.cellSize.toString(), placeholder: '8-60' })
              .fontSize(this.fontSize)
              .width(60)
              .height(32)
              .textAlign(TextAlign.Center)
              .type(InputType.Number)
              .onChange((v: string) => this.onCellSizeInput(v))
            Text('字体')
              .fontSize(this.fontSize)
            TextInput({ text: this.fontSize.toString(), placeholder: '10-22' })
              .fontSize(this.fontSize)
              .width(60)
              .height(32)
              .textAlign(TextAlign.Center)
              .type(InputType.Number)
              .onChange((v: string) => this.onFontSizeInput(v))
            Toggle({ type: ToggleType.Switch, isOn: this.autoFit })
              .onChange((isOn: boolean) => {
                this.autoFit = isOn;
                if (isOn) {
                  this.autoFitCells();
                }
              })
            Text('自适应')
              .fontSize(this.fontSize)
          }
          .width('100%')

          Stack({ alignContent: Alignment.TopStart }) {
            ForEach(this.getCells(), (cell: BitCell) => {
              Column() {
                Stack() {
                  Column()
                    .width(this.cellSize)
                    .height(this.cellSize)
                    .backgroundColor(this.cellColor(cell.bitIdx))
                    .border({ width: 1, color: '#000000' })
                    .borderRadius(2)
                  Text(this.cellBit(cell.bitIdx))
                    .fontSize(Math.max(6, Math.min(14, Math.floor(this.cellSize / 3))))
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#222222')
                }
                .width(this.cellSize)
                .height(this.cellSize)

                Text(cell.bitIdx + '')
                  .fontSize(Math.max(5, Math.min(8, Math.floor(this.cellSize / 4))))
                  .fontColor('#888888')
              }
              .width(this.cellSize)
              .height(this.cellSize + 18)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => this.onBitTap(cell.bitIdx))
              .position({
                x: this.cellX(cell.bitIdx),
                y: this.cellY(cell.bitIdx)
              })
            }, (cell: BitCell) => cell.key)
          }
          .width(this.cellSize * 32)
          .height(this.gridHeight())
          .border({ width: 1, color: '#CCCCCC' })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.onBitUp();
              return;
            }
            if (event.touches.length === 0) {
              return;
            }
            const t = event.touches[0];
            const bitIdx = this.cellFromPos(t.x, t.y);
            if (event.type === TouchType.Down) {
              if (bitIdx >= 0) {
                this.onBitDown(bitIdx);
              }
            } else if (event.type === TouchType.Move) {
              this.onBitMove(bitIdx);
            }
          })
          .gesture(PanGesture({ fingers: 1 })
            .onActionStart(() => {
            }))
        }
        .cardStyle()
      }
      .width('100%')
      .padding(12)
      .alignItems(HorizontalAlign.Start)
    }
    .backgroundColor('#F1F3F5')
    .scrollBar(BarState.Auto)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const w = Number(newArea.width) - 24;
      if (w !== this.gridWidth) {
        this.gridWidth = w;
        if (this.autoFit) {
          this.autoFitCells();
        }
      }
    })
  }
}