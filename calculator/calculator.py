import operator
import tkinter as tk
from decimal import Decimal, DecimalException, localcontext
from tkinter import font

OPERATIONS = {"+": operator.add, "−": operator.sub, "×": operator.mul, "÷": operator.truediv}


class Calculator:
    def __init__(self):
        self.clear()

    def clear(self):
        self.value = "0"
        self.left = None
        self.operation = None
        self.repeat = None
        self.fresh = True
        self.history = ""
        self.error = ""

    @staticmethod
    def display(value):
        if not value:
            return "0"
        with localcontext() as context:
            context.prec = 14
            value = value.normalize()
        if -7 <= value.adjusted() <= 13:
            return format(value, "f")
        return format(value, "E")

    def press(self, key):
        if key == "AC":
            self.clear()
            return
        if self.error:
            if key not in "0123456789.":
                return
            self.clear()

        if key in "0123456789.":
            if self.fresh:
                self.value = "0"
                if self.operation is None:
                    self.history = ""
                    self.repeat = None
            self.fresh = False
            if key == ".":
                if "." not in self.value:
                    self.value += "."
            elif len(self.value.replace(".", "").lstrip("-")) < 14:
                if self.value in ("0", "-0"):
                    self.value = self.value[:-1] + key
                else:
                    self.value += key
        elif key == "⌫":
            if not self.fresh and "E" not in self.value:
                self.value = self.value[:-1]
                if self.value in ("", "-"):
                    self.value = "0"
        elif key == "±":
            if self.operation and self.fresh:
                self.value = "0"
            self.value = self.value[1:] if self.value.startswith("-") else "-" + self.value
            self.fresh = "E" in self.value
        elif key == "%":
            if self.operation and self.fresh:
                self.value = "0"
            value = Decimal(self.value) / 100
            if self.operation in ("+", "−"):
                value *= self.left
            self.value = self.display(value)
            self.fresh = self.operation is None
        elif key in OPERATIONS:
            if self.operation and not self.fresh:
                self.calculate(self.left, self.operation, Decimal(self.value))
                if self.error:
                    return
            self.left = Decimal(self.value)
            self.operation = key
            self.repeat = None
            self.history = f"{self.display(self.left)} {key}"
            self.fresh = True
        elif key == "=":
            if self.operation:
                right = Decimal(self.value)
                self.repeat = (self.operation, right)
                self.calculate(self.left, self.operation, right)
                self.operation = None
            elif self.repeat:
                operation, right = self.repeat
                self.calculate(Decimal(self.value), operation, right)
            self.fresh = True

    def calculate(self, left, operation, right):
        self.history = f"{self.display(left)} {operation} {self.display(right)} ="
        try:
            self.value = self.display(OPERATIONS[operation](left, right))
        except DecimalException:
            self.error = "Деление на ноль" if operation == "÷" and not right else "Ошибка вычисления"


class Window:
    def __init__(self, root):
        self.root = root
        self.model = Calculator()
        root.title("Калькулятор")
        root.geometry("380x536")
        root.minsize(340, 480)
        root.configure(bg="#111321")
        face = "Segoe UI" if root.tk.call("tk", "windowingsystem") == "win32" else "DejaVu Sans"
        self.large = font.Font(family=face, size=34, weight="bold")
        self.small = font.Font(family=face, size=11)
        root.columnconfigure(0, weight=1)
        root.rowconfigure(2, weight=1)

        tk.Label(root, text="Калькулятор", bg="#111321", fg="#e9e7f5",
                 font=(face, 13, "bold"), anchor="w").grid(row=0, column=0, sticky="ew", padx=22, pady=(17, 13))
        screen = tk.Frame(root, bg="#1c2033", highlightthickness=1, highlightbackground="#333953")
        screen.grid(row=1, column=0, sticky="ew", padx=18, pady=(0, 12))
        self.history = tk.Label(screen, bg="#1c2033", fg="#acb4d5", anchor="e", font=self.small)
        self.history.pack(fill="x", padx=15, pady=(12, 0))
        self.result = tk.Label(screen, bg="#1c2033", fg="#f8f6ff", anchor="e", font=self.large)
        self.result.pack(fill="x", padx=14, pady=(0, 10))
        screen.bind("<Configure>", lambda event: self.refresh(event.width))

        keypad = tk.Frame(root, bg="#111321")
        keypad.grid(row=2, column=0, sticky="nsew", padx=15, pady=(0, 15))
        rows = [("AC", "±", "%", "÷"), ("7", "8", "9", "×"), ("4", "5", "6", "−"),
                ("1", "2", "3", "+"), ("⌫", "0", ",", "=")]
        for index in range(4):
            keypad.columnconfigure(index, weight=1, uniform="key")
        for row, keys in enumerate(rows):
            keypad.rowconfigure(row, weight=1, uniform="key")
            for column, key in enumerate(keys):
                self.add_button(keypad, key, row, column, face)
        root.bind("<Key>", self.keyboard)
        root.bind("<Control-c>", self.copy)
        self.refresh()

    def add_button(self, parent, key, row, column, face):
        if key == "=":
            bg, fg, hover = "#a99aff", "#171124", "#c3b9ff"
        elif key in OPERATIONS:
            bg, fg, hover = "#352c57", "#e0d8ff", "#47396e"
        elif row == 0 or key == "⌫":
            bg, fg, hover = "#2b3048", "#d7ddfa", "#3a4260"
        else:
            bg, fg, hover = "#22263b", "#f4f2ff", "#333952"
        button = tk.Button(parent, text=key, bg=bg, fg=fg, activebackground=hover,
                           activeforeground=fg, relief="flat", borderwidth=0,
                           highlightthickness=0, cursor="hand2", takefocus=False,
                           font=(face, 17, "bold"), command=lambda: self.press(key))
        button.grid(row=row, column=column, sticky="nsew", padx=3, pady=3)
        button.bind("<Enter>", lambda _: button.configure(bg=hover))
        button.bind("<Leave>", lambda _: button.configure(bg=bg))

    def refresh(self, width=None):
        width = width or self.result.master.winfo_width()
        message = self.model.error or self.model.value.replace(".", ",")
        for size in range(34, 11, -1):
            self.large.configure(size=size)
            if self.large.measure(message) <= max(width - 34, 265):
                break
        history = self.model.history.replace(".", ",")
        while history and self.small.measure(history) > max(width - 34, 265):
            history = history[1:]
        self.history.configure(text=history or " ")
        self.result.configure(text=message)

    def press(self, key):
        try:
            self.model.press("." if key == "," else key)
        except DecimalException:
            self.model.error = "Ошибка вычисления"
        self.refresh()
        return "break"

    def keyboard(self, event):
        keys = {"Return": "=", "KP_Enter": "=", "Escape": "AC",
                "Delete": "AC", "BackSpace": "⌫"}
        symbols = {"+": "+", "-": "−", "*": "×", "/": "÷", ",": ".", "=": "=", "%": "%"}
        key = keys.get(event.keysym) or symbols.get(event.char)
        if not key and event.char and event.char in "0123456789.":
            key = event.char
        if key:
            return self.press(key)

    def copy(self, _):
        if not self.model.error:
            self.root.clipboard_clear()
            self.root.clipboard_append(self.model.value.replace(".", ","))
        return "break"


if __name__ == "__main__":
    root = tk.Tk()
    Window(root)
    root.mainloop()
