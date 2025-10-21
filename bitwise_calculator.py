import os
import tkinter as tk
from tkinter import ttk, messagebox

class BinaryCalculator:
    def __init__(self, root):
        self.root = root
        self.root.title("数值计算/查看工具")
        self.root.geometry("880x600")

        # 变量初始化
        self.current_value = tk.StringVar(value="0")
        self.base_var = tk.IntVar(value=10)
        self.bit_size_var = tk.IntVar(value=64)  # 修改默认值为64
        self.little_endian_var = tk.BooleanVar(value=True)
        self.shift_amount_var = tk.IntVar(value=1)
        self.always_on_top_var = tk.BooleanVar(value=False)
        self.auto_detect_bits_var = tk.BooleanVar(value=True)
        self.scientific_mode_var = tk.BooleanVar(value=False)  # 科学计算模式变量
        self.pre_endian_var = self.little_endian_var.get()

        # 位选择相关变量
        self.selected_bits = set()
        self.select_start = None
        self.is_selecting = False
        self.click_start_pos = None

        self.history = os.path.expanduser("~") + "/.bitwise_calculator_history.txt"
        self.history_max_num = 100

        # 创建界面
        self.create_widgets()

    def load_history(self):
        try:
            if os.path.exists(self.history):
                with open(self.history, "r") as f:
                    return [line.strip() for line in f.readlines()]
            return []
        except FileNotFoundError:
            with open(self.history, 'w', encoding='utf-8') as file:
                file.write("")
            messagebox.showerror("错误", f"历史记录文件未找到: {self.history}")
            return []
        except Exception as e:
            messagebox.showerror("错误", f"加载历史记录时出错: {e}")
            return []

    def save_history(self, history):
        with open(self.history, "w") as f:
            for item in history:
                f.write(item + '\n')

    def update_history(self):
        history = self.load_history()
        history = history[::-1]  # 逆序排列历史记录
        self.history_combo['values'] = history

    def append_history(self, value):
        history = self.load_history()
        if value in history:
            history.remove(value)
        history.append(value)
        history = history[-self.history_max_num:]  # 保持最大记录数
        self.save_history(history)
        self.update_history()

    def detect_base(self, value_str):
        if not value_str:
            return self.base_var.get()

        # 1. 去除'_'字符
        processed_value = value_str.replace('_', '')

        # 2. 自动识别输入的进制
        original_base = self.base_var.get()
        detected_base = original_base

        # 检查是否有常见的进制前缀
        if processed_value.lower().startswith('0x'):
            detected_base = 16
            processed_value = processed_value[2:]
        elif processed_value.lower().startswith('0b'):
            detected_base = 2
            processed_value = processed_value[2:]
        elif processed_value.lower().startswith('0o'):
            detected_base = 8
            processed_value = processed_value[2:]

        # 3. 自动识别位宽，2的整数次幂向上对齐
        try:
            value = int(processed_value, detected_base)

            # 计算所需的最小位宽
            if value == 0:
                min_bit_size = 8  # 至少8位
            else:
                min_bit_size = value.bit_length()

            # 向上对齐到2的整数次幂
            if min_bit_size > 0:
                # 找到最接近的大于或等于min_bit_size的2的幂
                aligned_bit_size = 1
                while aligned_bit_size < min_bit_size:
                    aligned_bit_size <<= 1

                # 如果小于8位，至少设为8位
                aligned_bit_size = max(aligned_bit_size, 8)

                # 只在需要时更新位宽，避免不必要的变化
                if aligned_bit_size > self.bit_size_var.get():
                    self.bit_size_var.set(aligned_bit_size)
        except ValueError:
            pass  # 不是有效的数字，不做处理

        # 如果检测到的进制与当前设置不同，更新进制
        if detected_base != self.base_var.get():
            self.base_var.set(detected_base)

    def current_value_get(self):
        return self.current_value.get()

    def current_value_set(self, value):
        self.detect_base(value)
        self.update_history()
        self.current_value.set(value)

    def update_current_value_display(self):
        self.current_value_set(self.current_value_get())
        self.update_displays()

    def on_history_select(self, event):
        selected_value = self.history_combo.get()
        if selected_value:
            self.current_value_set(selected_value)
            self.calculate_and_update(add_to_history=True)

    def on_bit_size_event(self, event):
        selected_value = self.bit_size_combo.get()
        if selected_value:
            self.bit_size_var.set(int(selected_value))
            self.update_displays()

    def calculate_on_enter(self, event):
        self.current_value_set(self.history_combo.get())
        self.calculate_and_update(add_to_history=True)

    def on_history_keyrelease(self, event):
        self.current_value_set(self.history_combo.get())
        self.calculate_and_update(add_to_history=False)

    def create_widgets(self):
        # 主框架
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.pack(fill=tk.BOTH, expand=True)
        main_frame.bind('<Return>', self.calculate_on_enter)

        history_frame = ttk.LabelFrame(main_frame, text="数值输入", padding="10")
        history_frame.pack(fill=tk.X, pady=1)
        self.history_combo = ttk.Combobox(history_frame)
        self.history_combo.pack(fill=tk.X)
        self.update_history()
        self.history_combo.bind('<<ComboboxSelected>>', self.on_history_select)
        self.history_combo.bind('<Return>', self.calculate_on_enter)
        self.history_combo.bind('<KeyRelease>', self.on_history_keyrelease)

        # 输入和进制选择区域
        input_frame = ttk.LabelFrame(main_frame, text="操作和进制", padding="10")
        input_frame.pack(fill=tk.X, pady=1)
        input_frame.bind('<Return>', self.calculate_on_enter)

        # 数值输入
        input_span = 6
        ttk.Label(input_frame, text="结果:").grid(row=0, column=0, sticky=tk.W, padx=2, pady=1)
        self.entry = ttk.Entry(input_frame, textvariable=self.current_value, font=('Courier', 12))
        self.entry.grid(row=0, column=1, columnspan=input_span, sticky=tk.EW, padx=2, pady=1)

        ttk.Label(input_frame, text="移位:").grid(row=0, column=input_span+1, padx=2, sticky=tk.W)
        shift_spinbox = ttk.Spinbox(input_frame, from_=1, to=1024, width=5, textvariable=self.shift_amount_var)
        shift_spinbox.grid(row=0, column=input_span+2, padx=2, sticky=tk.W)
        ttk.Button(input_frame, text="<<", command=lambda: self.shift("left")).grid(row=0, column=input_span+3, padx=2, sticky=tk.W)
        ttk.Button(input_frame, text=">>", command=lambda: self.shift("right")).grid(row=0, column=input_span+4, padx=2, sticky=tk.W)
        ttk.Button(input_frame, text="=", command=self.calculate).grid(row=0, column=input_span+5, padx=2, pady=1, sticky=tk.W)
        ttk.Button(input_frame, text="C", command=self.clear).grid(row=0, column=input_span+6, padx=2, pady=1, sticky=tk.W)

        # 绑定输入事件，实现实时更新和Enter键计算
        self.entry.bind('<KeyRelease>', lambda event: self.update_current_value_display())
        self.entry.bind('<Return>', self.calculate_on_enter)

        # 进制选择
        ttk.Label(input_frame, text="输入进制:").grid(row=1, column=0, sticky=tk.W, padx=2, pady=1)
        ttk.Radiobutton(input_frame, text="2进制", variable=self.base_var, value=2,
                       command=self.update_displays).grid(row=1, column=1, padx=2, pady=1, sticky=tk.W)
        ttk.Radiobutton(input_frame, text="8进制", variable=self.base_var, value=8,
                       command=self.update_displays).grid(row=1, column=2, padx=2, pady=1, sticky=tk.W)
        ttk.Radiobutton(input_frame, text="10进制", variable=self.base_var, value=10,
                       command=self.update_displays).grid(row=1, column=3, padx=2, pady=1, sticky=tk.W)
        ttk.Radiobutton(input_frame, text="16进制", variable=self.base_var, value=16,
                       command=self.update_displays).grid(row=1, column=4, padx=2, pady=1, sticky=tk.W)

        # 位大小选择
        ttk.Label(input_frame, text="位大小:").grid(row=1, column=5, sticky=tk.W, padx=2, pady=1)
        # 使用下拉选择框替代单选按钮
        bit_sizes = [8, 16, 32, 64, 128, 256, 512, 1024]
        self.bit_size_combo = ttk.Combobox(input_frame, textvariable=self.bit_size_var, values=bit_sizes, width=5)
        self.bit_size_combo.grid(row=1, column=6, padx=2, pady=1, sticky=tk.W)
        self.bit_size_combo.bind("<<ComboboxSelected>>", self.on_bit_size_event)
        self.bit_size_combo.bind('<KeyRelease>', self.on_bit_size_event)
        self.bit_size_combo.bind('<Return>', self.on_bit_size_event)

        ttk.Radiobutton(input_frame, text="小端序", variable=self.little_endian_var, value=True,
                       command=self.on_endian_change).grid(row=1, column=7, padx=2, pady=1, sticky=tk.W)
        ttk.Radiobutton(input_frame, text="大端序", variable=self.little_endian_var, value=False,
                       command=self.on_endian_change).grid(row=1, column=8, padx=2, pady=1, sticky=tk.W)

        # 科学计算模式选项
        ttk.Checkbutton(input_frame, text="科学计算", variable=self.scientific_mode_var,
                       command=self.on_scientific_mode_change).grid(row=1, column=9, padx=2, pady=1, sticky=tk.W)

        # 置顶选项
        ttk.Checkbutton(input_frame, text="窗口置顶", variable=self.always_on_top_var,
                       command=self.toggle_always_on_top).grid(row=1, column=10, padx=2, pady=1, sticky=tk.W)

        # 创建新的容器frame，用于放置result_frame和selection_frame
        display_container = ttk.Frame(main_frame)
        display_container.pack(fill=tk.X, pady=1)

        # 转换结果显示区域
        result_frame = ttk.LabelFrame(display_container, text="进制转换结果", padding="10")
        result_frame.grid(row=0, column=0, sticky=tk.NSEW, padx=(0, 5))

        # 二进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(result_frame, text="二进制: ", font=("Courier", 10)).grid(row=0, column=0, sticky=tk.W, padx=2, pady=1)
        self.binary_value = ttk.Entry(result_frame, font=("Courier", 10), width=25)
        self.binary_value.grid(row=0, column=1, sticky=tk.W, padx=2, pady=1)
        self.binary_value.config(state='readonly')

        # 八进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(result_frame, text="八进制: ", font=("Courier", 10)).grid(row=1, column=0, sticky=tk.W, padx=2, pady=1)
        self.octal_value = ttk.Entry(result_frame, font=(("Courier", 10)), width=25)
        self.octal_value.grid(row=1, column=1, sticky=tk.W, padx=2, pady=1)
        self.octal_value.config(state='readonly')

        # 十进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(result_frame, text="十进制: ", font=("Courier", 10)).grid(row=2, column=0, sticky=tk.W, padx=2, pady=1)
        self.decimal_value = ttk.Entry(result_frame, font=(("Courier", 10)), width=25)
        self.decimal_value.grid(row=2, column=1, sticky=tk.W, padx=2, pady=1)
        self.decimal_value.config(state='readonly')

        # 十六进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(result_frame, text="十六进制: ", font=("Courier", 10)).grid(row=3, column=0, sticky=tk.W, padx=2, pady=1)
        self.hex_value = ttk.Entry(result_frame, font=(("Courier", 10)), width=25)
        self.hex_value.grid(row=3, column=1, sticky=tk.W, padx=2, pady=1)
        self.hex_value.config(state='readonly')

        # 位显示区域
        bit_frame = ttk.LabelFrame(main_frame, text="位显示", padding="10")
        bit_frame.pack(fill=tk.BOTH, expand=True, pady=1)

        # 创建滚动条和画布容器
        bit_container = ttk.Frame(bit_frame)
        bit_container.pack(fill=tk.BOTH, expand=True, padx=2, pady=1)

        # 添加垂直滚动条
        v_scrollbar = ttk.Scrollbar(bit_container, orient=tk.VERTICAL)
        v_scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        # 添加水平滚动条
        h_scrollbar = ttk.Scrollbar(bit_container, orient=tk.HORIZONTAL)
        h_scrollbar.pack(side=tk.BOTTOM, fill=tk.X)

        # 创建画布
        self.bit_canvas = tk.Canvas(bit_container, bg="white",
                                   yscrollcommand=v_scrollbar.set,
                                   xscrollcommand=h_scrollbar.set)
        self.bit_canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

        v_scrollbar.config(command=self.bit_canvas.yview)
        h_scrollbar.config(command=self.bit_canvas.xview)

        # 绑定鼠标事件到位画布
        self.bit_canvas.bind("<Button-1>", self.on_bit_click)
        self.bit_canvas.bind("<B1-Motion>", self.on_bit_drag)
        self.bit_canvas.bind("<ButtonRelease-1>", self.on_bit_release)
        # 添加双击事件，双击时改变位的值
        self.bit_canvas.bind("<Double-1>", self.on_bit_double_click)

        # 位选择结果显示区域
        self.selection_frame = ttk.LabelFrame(display_container, text="位选择结果：未选择任何位", padding="10")
        self.selection_frame.grid(row=0, column=1, sticky=tk.NSEW, padx=(5, 0))
        display_container.grid_columnconfigure(0, weight=1)
        display_container.grid_columnconfigure(1, weight=1)

        # 位选择结果进制显示
        # 二进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(self.selection_frame, text="二进制: ", font=("Courier", 10)).grid(row=1, column=0, sticky=tk.W, padx=2, pady=1)
        self.selected_binary_value = ttk.Entry(self.selection_frame, font=("Courier", 10), width=25)
        self.selected_binary_value.grid(row=1, column=1, sticky=tk.W, padx=2, pady=1)
        self.selected_binary_value.config(state='readonly')

        # 八进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(self.selection_frame, text="八进制: ", font=("Courier", 10)).grid(row=2, column=0, sticky=tk.W, padx=2, pady=1)
        self.selected_octal_value = ttk.Entry(self.selection_frame, font=("Courier", 10), width=25)
        self.selected_octal_value.grid(row=2, column=1, sticky=tk.W, padx=2, pady=1)
        self.selected_octal_value.config(state='readonly')

        # 十进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(self.selection_frame, text="十进制: ", font=("Courier", 10)).grid(row=3, column=0, sticky=tk.W, padx=2, pady=1)
        self.selected_decimal_value = ttk.Entry(self.selection_frame, font=("Courier", 10), width=25)
        self.selected_decimal_value.grid(row=3, column=1, sticky=tk.W, padx=2, pady=1)
        self.selected_decimal_value.config(state='readonly')

        # 十六进制显示：左侧为标签显示描述，右侧为文本框显示数值
        ttk.Label(self.selection_frame, text="十六进制: ", font=("Courier", 10)).grid(row=4, column=0, sticky=tk.W, padx=2, pady=1)
        self.selected_hex_value = ttk.Entry(self.selection_frame, font=("Courier", 10), width=25)
        self.selected_hex_value.grid(row=4, column=1, sticky=tk.W, padx=2, pady=1)
        self.selected_hex_value.config(state='readonly')

        # 位选择操作按钮
        selection_buttons_frame = ttk.Frame(self.selection_frame)
        selection_buttons_frame.grid(row=5, column=0, columnspan=2, sticky=tk.W, pady=1)

        ttk.Button(selection_buttons_frame, text="清除选择", command=self.clear_selection).grid(row=0, column=0, padx=2)
        ttk.Button(selection_buttons_frame, text="反转选择位", command=self.invert_selected_bits).grid(row=0, column=1, padx=2)

        # 初始化显示
        self.update_displays()

    def auto_detect_bit_size(self, value):
        """自动识别数值所需的位宽"""
        if value == 0:
            return 8  # 0可以用8位表示

        # 计算需要的位数
        if value < 0:
            # 对于负数，需要额外一位表示符号
            bits_needed = value.bit_length() + 1
        else:
            bits_needed = value.bit_length()

        # 找到最小的标准位宽
        standard_sizes = [8, 16, 32, 64, 128, 256, 512, 1024]
        for size in standard_sizes:
            if bits_needed <= size:
                return size

        # 如果超过1024位，返回1024
        return 1024

    def on_endian_change(self):
        """处理端序单选按钮变化"""
        # 获取新的端序状态
        is_little_endian = self.little_endian_var.get()
        if is_little_endian == self.pre_endian_var:
            return
        self.pre_endian_var = is_little_endian

        # 获取当前值
        value = self.get_current_value()
        bit_size = self.bit_size_var.get()

        # 如果位大小是8位，不需要端序转换
        if bit_size == 8:
            messagebox.showinfo("提示", "8位数据无需端序转换")
            return

        # 根据位大小和新的端序状态执行转换
        if bit_size == 16:
            if is_little_endian:
                # 转换为小端序
                result = ((value & 0xFF) << 8) | ((value >> 8) & 0xFF)
            else:
                # 转换为大端序
                result = ((value & 0xFF) << 8) | ((value >> 8) & 0xFF)
        elif bit_size == 32:
            if is_little_endian:
                # 转换为小端序
                result = ((value & 0xFF) << 24) | (((value >> 8) & 0xFF) << 16) | \
                         (((value >> 16) & 0xFF) << 8) | ((value >> 24) & 0xFF)
            else:
                # 转换为大端序
                result = ((value & 0xFF) << 24) | (((value >> 8) & 0xFF) << 16) | \
                         (((value >> 16) & 0xFF) << 8) | ((value >> 24) & 0xFF)
        elif bit_size == 64:
            if is_little_endian:
                # 转换为小端序
                result = ((value & 0xFF) << 56) | (((value >> 8) & 0xFF) << 48) | \
                         (((value >> 16) & 0xFF) << 40) | (((value >> 24) & 0xFF) << 32) | \
                         (((value >> 32) & 0xFF) << 24) | (((value >> 40) & 0xFF) << 16) | \
                         (((value >> 48) & 0xFF) << 8) | ((value >> 56) & 0xFF)
            else:
                # 转换为大端序
                result = ((value & 0xFF) << 56) | (((value >> 8) & 0xFF) << 48) | \
                         (((value >> 16) & 0xFF) << 40) | (((value >> 24) & 0xFF) << 32) | \
                         (((value >> 32) & 0xFF) << 24) | (((value >> 40) & 0xFF) << 16) | \
                         (((value >> 48) & 0xFF) << 8) | ((value >> 56) & 0xFF)
        else:
            # 按32bit为单位进行端序转换，但保持32bit之间的位置不变
            dwords_needed = (bit_size + 31) // 32  # 计算需要的32位单元数量
            bytes_needed = dwords_needed * 4  # 转换为字节数

            try:
                # 将数值转换为字节数组
                value_bytes = value.to_bytes(bytes_needed, byteorder='big')  # 始终使用大端序作为中间表示

                # 按32位(4字节)为单位处理每个单元
                result_bytes = b''
                for i in range(0, bytes_needed, 4):
                    # 获取32位单元的4个字节
                    dword_bytes = value_bytes[i:i+4]

                    reversed_dword = dword_bytes[::-1]
                    result_bytes += reversed_dword

                # 从字节数组转换回整数
                result = int.from_bytes(result_bytes, byteorder='big')
            except OverflowError:
                messagebox.showerror("错误", f"无法处理{bit_size}位的端序转换")
                return

        base = self.base_var.get()
        self.current_value_set(self.format_number(result, base))
        self.update_displays()

    def toggle_always_on_top(self):
        """切换窗口置顶状态"""
        self.root.attributes('-topmost', self.always_on_top_var.get())

    def on_scientific_mode_change(self):
        """当科学计算模式改变时的回调方法"""
        # 当科学计算模式改变时，可以在这里添加需要的更新逻辑
        # 例如，如果当前有输入，可以重新计算并显示结果
        current_value = self.current_value_get()
        if current_value and current_value != "0":
            self.calculate_and_update(add_to_history=False)

    def get_current_value(self):
        """获取当前输入的值并转换为整数"""
        try:
            value_str = self.current_value_get().strip()
            if not value_str:
                return 0

            base = self.base_var.get()
            value = int(value_str, base)

            # 根据位大小进行截断
            bit_size = self.bit_size_var.get()
            max_value = (1 << bit_size) - 1
            if value > max_value:
                value = value & max_value
                self.current_value_set(self.format_number(value, base))

            return value
        except ValueError:
            # 输入无效时不弹出错误，而是返回0，这样用户可以在输入过程中看到实时更新
            return 0

    def format_number(self, value, base):
        """根据进制格式化数字，支持整数和浮点数"""
        # 如果是浮点数，只支持十进制格式化
        if isinstance(value, float):
            # 检查是否是整数形式的浮点数
            if value.is_integer():
                return str(int(value))

            # 处理浮点数精度问题，对于小数结果进行适当的四舍五入
            # 尝试检测并修复常见的精度问题，如0.1+0.2=0.30000000000000004
            # 先尝试格式化为15位有效数字
            rounded_value = round(value, 15)
            # 然后检查是否可以用更少的小数位表示
            for i in range(15, 0, -1):
                test_value = round(value, i)
                if abs(test_value - value) < 1e-10:
                    rounded_value = test_value
                    break

            # 转换为字符串并移除末尾的0
            str_value = str(rounded_value)
            # 检查是否有小数点，并且小数点后只有0
            if '.' in str_value:
                # 移除末尾的0
                str_value = str_value.rstrip('0')
                # 如果小数点后没有数字，移除小数点
                if str_value.endswith('.'):
                    str_value = str_value[:-1]

            return str_value

        # 整数的格式化
        if base == 2:
            return bin(value)
        elif base == 8:
            return oct(value)
        elif base == 10:
            return str(value)
        elif base == 16:
            return '0x' + hex(value)[2:].upper()

    def update_displays(self, event=None):
        """更新所有显示"""
        value = self.get_current_value()

        # 更新进制显示
        # 二进制值显示
        self.binary_value.config(state='normal')
        self.binary_value.delete(0, tk.END)
        self.binary_value.insert(0, f"{bin(value)[2:]}")
        self.binary_value.config(state='readonly')

        # 八进制值显示
        self.octal_value.config(state='normal')
        self.octal_value.delete(0, tk.END)
        self.octal_value.insert(0, f"{oct(value)[2:]}")
        self.octal_value.config(state='readonly')

        # 十进制值显示
        self.decimal_value.config(state='normal')
        self.decimal_value.delete(0, tk.END)
        self.decimal_value.insert(0, f"{str(value)}")
        self.decimal_value.config(state='readonly')

        # 十六进制值显示
        self.hex_value.config(state='normal')
        self.hex_value.delete(0, tk.END)
        self.hex_value.insert(0, f"{hex(value)[2:].upper()}")
        self.hex_value.config(state='readonly')

        # 更新位显示
        self.update_bit_display(value)

        # 更新位选择结果
        self.update_selection_display()

    def update_bit_display(self, value):
        """更新位可视化显示"""
        self.bit_canvas.delete("all")

        bit_size = self.bit_size_var.get()
        bits = format(value, f'0{bit_size}b')

        # 固定每行显示32位，确保32位和64位的每行宽度一致
        rows = 1 if bit_size <= 32 else 2
        bits_per_row = 32

        # 增大单元格宽度和高度，使位显示更清晰
        cell_width = 25  # 从20增加到25
        cell_height = 25  # 从20增加到25
        start_x = 10
        start_y = 10

        # 计算需要的行数
        rows = (bit_size + bits_per_row - 1) // bits_per_row

        # 计算画布所需尺寸
        canvas_width = bits_per_row * cell_width + 20
        canvas_height = rows * (cell_height + 20) + 20

        self.bit_canvas.config(scrollregion=(0, 0, canvas_width, canvas_height))

        # 存储位矩形的位置信息，用于点击检测
        self.bit_rects = {}

        for row in range(rows):
            # 计算当前行显示的位
            start_bit = row * bits_per_row
            end_bit = min((row + 1) * bits_per_row, bit_size)
            row_bits = bits[start_bit:end_bit]

            for i, bit in enumerate(row_bits):
                x = start_x + i * cell_width
                y = start_y + row * (cell_height + 20)  # 行间距

                # 计算实际位索引（从最高位到最低位）
                bit_index = bit_size - (start_bit + i) - 1

                # 确定颜色：选中位使用不同颜色
                if bit_index in self.selected_bits:
                    color = "lightblue" if bit == '1' else "lightyellow"
                else:
                    color = "lightgreen" if bit == '1' else "lightcoral"

                # 绘制位值框
                rect_id = self.bit_canvas.create_rectangle(x, y, x + cell_width, y + cell_height,
                                               fill=color, outline="black", width=1)

                # 存储矩形信息用于点击检测
                self.bit_rects[rect_id] = bit_index

                # 绘制位值
                font_size = 8 if cell_width < 15 else 10
                self.bit_canvas.create_text(x + cell_width/2, y + cell_height/2,
                                          text=bit, font=("Arial", font_size, "bold"))

                # 每隔4位显示一次位索引，避免过于拥挤
                if bit_index % 1 == 0:
                    self.bit_canvas.create_text(x + cell_width/2, y + cell_height + 8,
                                              text=str(bit_index), font=("Arial", 6))

    def on_bit_double_click(self, event):
        """处理位双击事件，双击时改变位的值"""
        x = self.bit_canvas.canvasx(event.x)
        y = self.bit_canvas.canvasy(event.y)

        # 找到被双击的矩形
        clicked_items = self.bit_canvas.find_overlapping(x, y, x, y)

        for item in clicked_items:
            if item in self.bit_rects:
                bit_index = self.bit_rects[item]
                self.toggle_bit(bit_index)
                break

    def on_bit_click(self, event):
        """处理位点击事件"""
        # 记录点击开始位置
        self.click_start_pos = (event.x, event.y)

        x = self.bit_canvas.canvasx(event.x)
        y = self.bit_canvas.canvasy(event.y)

        # 找到被点击的矩形
        clicked_items = self.bit_canvas.find_overlapping(x, y, x, y)

        for item in clicked_items:
            if item in self.bit_rects:
                bit_index = self.bit_rects[item]

                # 如果按住了Shift键，则添加到选择集（不连续选择）
                if event.state & 0x1:  # Shift键
                    if bit_index in self.selected_bits:
                        self.selected_bits.remove(bit_index)
                    else:
                        self.selected_bits.add(bit_index)
                    self.update_displays()
                else:
                    # 普通点击：选择单个位（不连续）
                    self.is_selecting = True
                    self.select_start = bit_index
                    self.selected_bits.clear()
                    self.selected_bits.add(bit_index)
                    self.update_displays()
                break

    def on_bit_drag(self, event):
        """处理位拖动选择事件"""
        if not self.is_selecting:
            return

        x = self.bit_canvas.canvasx(event.x)
        y = self.bit_canvas.canvasy(event.y)

        # 找到被拖动的矩形
        dragged_items = self.bit_canvas.find_overlapping(x, y, x, y)

        for item in dragged_items:
            if item in self.bit_rects:
                bit_index = self.bit_rects[item]

                # 选择从起始点到当前点的所有位
                self.selected_bits.clear()
                start = min(self.select_start, bit_index)
                end = max(self.select_start, bit_index)

                for i in range(start, end + 1):
                    self.selected_bits.add(i)

                self.update_displays()
                break

    def on_bit_release(self, event):
        """处理位释放事件"""
        if not self.is_selecting:
            return

        self.is_selecting = False
        self.click_start_pos = None

        # 只更新显示，不再切换位值（位值切换由双击事件处理）
        self.update_displays()

    def toggle_bit(self, bit_index):
        """切换指定位的值"""
        value = self.get_current_value()
        mask = 1 << bit_index
        new_value = value ^ mask  # 使用异或操作切换位

        base = self.base_var.get()
        self.current_value_set(self.format_number(new_value, base))

        # 切换完位值后，将该位添加到选择集中
        self.selected_bits.clear()
        self.selected_bits.add(bit_index)
        self.update_displays()

    def update_selection_display(self):
        """更新位选择结果显示"""
        if not self.selected_bits:
            self.selection_frame.config(text="位选择结果：未选择任何位")
            # 清空所有文本框
            for entry in [self.selected_binary_value, self.selected_octal_value, self.selected_decimal_value, self.selected_hex_value]:
                entry.config(state='normal')
                entry.delete(0, tk.END)
                entry.config(state='readonly')
            return

        # 计算选中的位的值
        selected_value = 0

        # 排序选中的位，方便显示
        sorted_bits = sorted(self.selected_bits)
        min_bit = sorted_bits[0]
        max_bit = sorted_bits[-1]

        # 检查是否是连续的位选择
        is_contiguous = all(sorted_bits[i] == sorted_bits[i-1] + 1 for i in range(1, len(sorted_bits)))

        for bit_count, bit_index in enumerate(sorted_bits):
            current_value = self.get_current_value()
            if (current_value >> bit_index) & 1:
                selected_value |= (1 << bit_count)

        # 更新选择信息
        if is_contiguous:
            # 如果是连续选择，显示范围
            self.selection_frame.config(text=f"位选择结果：选择了位 {max_bit} 到 {min_bit} (共 {len(self.selected_bits)} 位)")
        else:
            # 如果是不连续选择，列出所有选中的位
            bit_list = ", ".join(str(bit) for bit in sorted_bits)
            self.selection_frame.config(text=f"位选择结果：选择了位: {bit_list} (共 {len(self.selected_bits)} 位)")

        # 二进制值显示
        self.selected_binary_value.config(state='normal')
        self.selected_binary_value.delete(0, tk.END)
        self.selected_binary_value.insert(0, f"{format(selected_value, f'0{bit_count+1}b')}")
        self.selected_binary_value.config(state='readonly')

        # 八进制值显示
        self.selected_octal_value.config(state='normal')
        self.selected_octal_value.delete(0, tk.END)
        self.selected_octal_value.insert(0, f"{oct(selected_value)[2:]}")
        self.selected_octal_value.config(state='readonly')

        # 十进制值显示
        self.selected_decimal_value.config(state='normal')
        self.selected_decimal_value.delete(0, tk.END)
        self.selected_decimal_value.insert(0, f"{selected_value}")
        self.selected_decimal_value.config(state='readonly')

        # 十六进制值显示
        self.selected_hex_value.config(state='normal')
        self.selected_hex_value.delete(0, tk.END)
        self.selected_hex_value.insert(0, f"{format(selected_value, f'0X')}")
        self.selected_hex_value.config(state='readonly')

    def clear_selection(self):
        """清除位选择"""
        self.selected_bits.clear()
        self.update_displays()

    def invert_selected_bits(self):
        """反转选中的位"""
        if not self.selected_bits:
            return

        value = self.get_current_value()

        for bit_index in self.selected_bits:
            mask = 1 << bit_index
            value ^= mask  # 使用异或操作切换位

        base = self.base_var.get()
        self.current_value_set(self.format_number(value, base))
        self.update_displays()

    def calculate_and_update(self, add_to_history=True):
        # 检查当前输入是否包含运算符
        expression = self.current_value_get()
        if any(op in expression for op in '+-*/&|^'):
            self.calculate(add_to_history=add_to_history)
        else:
            # 如果没有运算符，只是更新显示
            if add_to_history and expression != "0" and expression != "":
                self.append_history(self.current_value_get())
            self.update_current_value_display()
            self.update_displays()

    def parse_expression(self, expression):
        # 简单的词法分析器将表达式分解为标记
        def tokenize(expr, scientific_mode):
            tokens = []
            i = 0
            while i < len(expr):
                char = expr[i]
                if char.isspace():
                    i += 1
                elif char.isdigit() or (char.lower() in 'abcdef' and \
                                      (i == 0 or expr[i-1] == 'x' or expr[i-1] == 'X')) or \
                                      (char == '.' and scientific_mode):
                    # 处理数字和十六进制前缀
                    start = i
                    is_hex = False
                    # 检查是否是十六进制前缀
                    if char == '0' and i + 1 < len(expr) and expr[i+1].lower() == 'x':
                        is_hex = True
                        i += 2  # 跳过0和x
                    else:
                        i += 1
                    # 收集数字部分
                    while i < len(expr):
                        next_char = expr[i]
                        if next_char.isdigit() or next_char == '_' or \
                           (is_hex and next_char.lower() in 'abcdef'):
                            i += 1
                        else:
                            break
                    tokens.append(('NUMBER', expr[start:i]))
                elif char == '0' and i + 1 < len(expr) and expr[i+1].lower() in ['x', 'b', 'd']:
                    # 处理以0x、0b或0d开头的数字
                    start = i
                    i += 2  # 跳过0和x/b
                    while i < len(expr) and (expr[i].isalnum() or expr[i] == '_'):
                        i += 1
                    tokens.append(('NUMBER', expr[start:i]))
                elif char in '+-*/&|^()<<>>':
                    # 解析运算符和括号
                    if char == '<' and i+1 < len(expr) and expr[i+1] == '<':
                        tokens.append(('OPERATOR', '<<'))
                        i += 2
                    elif char == '>' and i+1 < len(expr) and expr[i+1] == '>':
                        tokens.append(('OPERATOR', '>>'))
                        i += 2
                    else:
                        tokens.append(('OPERATOR', char))
                        i += 1
                else:
                    # 检查是否是单独的'0b'、'0x'或'0d'
                    if i + 1 < len(expr) and expr[i:i+2].lower() == '0b':
                        tokens.append(('NUMBER', expr[i:i+2]))
                        i += 2
                    elif i + 1 < len(expr) and expr[i:i+2].lower() == '0x':
                        tokens.append(('NUMBER', expr[i:i+2]))
                        i += 2
                    elif i + 1 < len(expr) and expr[i:i+2].lower() == '0d':
                        tokens.append(('NUMBER', expr[i:i+2]))
                        i += 2
                    else:
                        # 尝试处理可能的十六进制字符
                        if char.lower() in 'abcdef':
                            # 检查是否是十六进制数字（前面可以是数字、x/X、运算符或表达式开头）
                            if i == 0 or expr[i-1] in '0123456789xX+-*/&|^()':
                                start = i
                                i += 1
                                while i < len(expr) and (expr[i].isdigit() or expr[i].lower() in 'abcdef' or expr[i] == '_'):
                                    i += 1
                                tokens.append(('NUMBER', expr[start:i]))
                                continue
                        raise ValueError(f"Invalid character in expression: {char}")
            return tokens

        # 递归下降解析器实现
        def parse(tokens, scientific_mode):
            i = [0]  # 使用列表作为可变对象来跟踪位置

            def parse_expression():  # 处理加减法
                left = parse_term()
                while i[0] < len(tokens) and tokens[i[0]][1] in ['+', '-']:
                    op = tokens[i[0]][1]
                    i[0] += 1
                    right = parse_term()
                    if op == '+' :
                        left = left + right
                    else:
                        left = left - right
                return left

            def parse_term():  # 处理乘除法
                left = parse_factor()
                while i[0] < len(tokens) and tokens[i[0]][1] in ['*', '/']:
                    op = tokens[i[0]][1]
                    i[0] += 1
                    right = parse_factor()
                    if op == '*':
                        left = left * right
                    else:
                        # 在科学计算模式下使用浮点数除法，否则使用整数除法
                        if scientific_mode:
                            left = left / right  # 浮点数除法
                        else:
                            left = left // right  # 整数除法
                return left

            def parse_factor():  # 处理位运算和括号
                left = parse_atom()
                while i[0] < len(tokens) and tokens[i[0]][1] in ['&', '|', '^', '<<', '>>']:
                    op = tokens[i[0]][1]
                    i[0] += 1
                    right = parse_atom()
                    if op == '&':
                        left = left & right
                    elif op == '|':
                        left = left | right
                    elif op == '^':
                        if self.scientific_mode_var.get():
                            # 科学计算模式下，^ 作为次方操作
                            left = left ** right
                        else:
                            # 普通模式下，^ 作为异或操作
                            left = left ^ right
                    elif op == '<<':
                        left = left << right
                    elif op == '>>':
                        left = left >> right
                return left

            def parse_atom():
                token = tokens[i[0]]
                i[0] += 1
                if token[0] == 'NUMBER':
                    # 处理不同进制的数字
                    num_str = token[1].lower()

                    # 特殊处理：单独的0b或0x作为十进制0处理
                    if num_str == '0b' or num_str == '0x' or num_str == '0d':
                        return 0

                    # 处理不同进制的数字
                    if num_str.startswith('0x'):
                        try:
                            return int(num_str, 16)
                        except ValueError:
                            # 如果无法解析为十六进制，则作为十进制0处理
                            return 0
                    elif num_str.startswith('0b'):
                        try:
                            return int(num_str, 2)
                        except ValueError:
                            # 如果无法解析为二进制，则作为十进制0处理
                            return 0
                    elif num_str.startswith('0d'):
                        try:
                            # 0d前缀表示十进制
                            return int(num_str[2:].replace('_', ''))
                        except ValueError:
                            # 如果无法解析为十进制，则作为十进制0处理
                            return 0
                    else:
                        # 尝试转换为十进制（包括科学记数法）
                        try:
                            # 直接使用float转换，它能处理科学记数法
                            float_val = float(num_str.replace('_', ''))
                            # 如果是整数形式的浮点数但不是科学记数法，返回整数
                            if float_val.is_integer() and 'e' not in num_str.lower():
                                return int(float_val)
                            return float_val
                        except ValueError:
                            # 可能是十六进制但没有前缀
                            try:
                                return int(num_str.replace('_', ''), 16)
                            except ValueError:
                                raise ValueError(f"Invalid number format: {num_str}")
                elif token[1] == '(':
                    expr_val = parse_expression()
                    # 确保右括号存在
                    if i[0] >= len(tokens) or tokens[i[0]][1] != ')':
                        raise ValueError("Missing closing parenthesis")
                    i[0] += 1
                    return expr_val
                else:
                    raise ValueError(f"Unexpected token: {token}")

            return parse_expression()

        try:
            tokens = tokenize(expression, self.scientific_mode_var.get())
            result = parse(tokens, self.scientific_mode_var.get())
            return result
        except Exception as e:
            return None

    def calculate(self, add_to_history=True):
        """执行计算"""
        try:
            input_text = self.current_value_get()
            # 将表达式中的数字转换为十进制进行计算
            base = self.base_var.get()

            if add_to_history and input_text != "0" and input_text != "":
                self.append_history(input_text)

            result = self.parse_expression(input_text)
            if result is None:
                return

            # 如果结果是浮点数，不进行位运算和截断
            if isinstance(result, float):
                pass  # 保留浮点数原样
            else:
                # 根据位大小截断结果
                bit_size = self.bit_size_var.get()
                max_value = (1 << bit_size) - 1
                if result > max_value:
                    result = result & max_value
                elif result < 0:
                    # 对于负数，使用补码表示
                    result = (1 << bit_size) + result
                    result = result & max_value

            # 更新当前值
            self.current_value_set(self.format_number(result, base))
            self.update_displays()

        except Exception as e:
            messagebox.showerror("错误", f"计算失败: {str(e)}")

    def clear(self):
        """清除当前值"""
        self.current_value_set("0")
        self.update_displays()

    def shift(self, direction):
        """执行移位操作"""
        value = self.get_current_value()
        amount = self.shift_amount_var.get()

        if direction == "left":
            result = value << amount
        else:  # right
            result = value >> amount

        # 根据位大小截断结果
        bit_size = self.bit_size_var.get()
        max_value = (1 << bit_size) - 1
        result = result & max_value

        base = self.base_var.get()
        self.current_value_set(self.format_number(result, base))
        self.update_displays()

    def endian_convert(self):
        self.little_endian_var.set(not self.little_endian_var.get())
        self.on_endian_change()

    def bitwise_not(self):
        """按位取反操作"""
        value = self.get_current_value()
        bit_size = self.bit_size_var.get()

        # 按位取反并根据位大小截断
        result = (~value) & ((1 << bit_size) - 1)

        base = self.base_var.get()
        self.current_value_set(self.format_number(result, base))
        self.update_displays()

if __name__ == "__main__":
    root = tk.Tk()
    app = BinaryCalculator(root)
    root.mainloop()