# Qwen (千问) 输入框注入方案尝试记录

## 问题描述

Qwen 使用 React + Slate.js 的 `contentEditable` 富文本编辑器。当前方案使用 `execCommand('insertText')` 注入文本，文本在界面上**看起来**填入了，但 Slate.js 的内部状态（`value`）没有更新，导致发送按钮保持禁用状态。

## 尝试方案

### [ ] 方案1：`execCommand('insertText')` — 当前方案（已知失败）

当前正在使用的方案。问题：文本显示在输入框中，但 Slate.js 内部状态未更新。

**主要问题**：Slate.js 通过 `beforeinput` 事件监听输入，虽然 `execCommand` 产生 `isTrusted=true` 的事件，但 Qwen 的 Slate 配置可能使用了自定义 `onChange` 处理，需要特定格式的 Slate Operation 才能触发。

---

### [*] 方案2：`beforeinput` + DOM 操作 — **当前尝试中**

替换了原有的 `execCommand('insertText')`。原理是手动分发 `beforeinput` 事件让 Slate.js 的内部状态同步更新。

```javascript
// 对每个字符:
el.focus();
var sel = window.getSelection();
var range = document.createRange();
range.setStart(el, 0);
range.collapse(true);
sel.removeAllRanges();
sel.addRange(range);

// Step 1: dispatch beforeinput (Slate 监听这个)
el.dispatchEvent(new InputEvent('beforeinput', {
  inputType: 'insertText',
  data: char,
  bubbles: true,
  cancelable: true
}));

// Step 2: 直接修改 DOM
var textNode = document.createTextNode(char);
range.insertNode(textNode);
range.collapse(false);

// Step 3: dispatch input
el.dispatchEvent(new InputEvent('input', {
  inputType: 'insertText',
  data: char,
  bubbles: true,
  cancelable: true
}));
```

**原理**：Slate.js 通过 `beforeinput` 事件的 `inputType` 和 `data` 来决定如何更新其内部状态。如果先发 `beforeinput` 让 Slate 处理，再手动修改 DOM，可能让 Slate 内部状态与 DOM 同步。

---

### [ ] 方案3：模拟粘贴（DataTransfer + `insertFromPaste`）

模拟粘贴操作，Slate.js 通常对粘贴有专门的 `insertFromPaste` 处理逻辑。

```javascript
el.focus();
var dt = new DataTransfer();
dt.setData('text/plain', message);

// Slate 监听 beforeinput with inputType 'insertFromPaste'
el.dispatchEvent(new InputEvent('beforeinput', {
  inputType: 'insertFromPaste',
  dataTransfer: dt,
  bubbles: true,
  cancelable: true
}));

// 修改 DOM
el.innerHTML = ''; // 或保留原有内容
el.appendChild(document.createTextNode(message));

el.dispatchEvent(new InputEvent('input', {
  inputType: 'insertFromPaste',
  data: message,
  bubbles: true,
  cancelable: true
}));
```

**原理**：Slate.js 对粘贴有独立的处理路径 (`insertFromPaste`)，可能会正确合并到内部状态中。

---

### [ ] 方案4：字符级键盘事件 + 原生输入模拟

完全模拟键盘输入：对每个字符触发 `keydown` → `beforeinput` → `input` → `keyup`。

```javascript
for (var i = 0; i < message.length; i++) {
  var ch = message[i];
  el.dispatchEvent(new KeyboardEvent('keydown', { key: ch, bubbles: true }));
  
  el.dispatchEvent(new InputEvent('beforeinput', {
    inputType: 'insertText',
    data: ch,
    bubbles: true,
    cancelable: true
  }));
  
  // DOM 修改
  var textNode = document.createTextNode(ch);
  var sel = window.getSelection();
  var range = sel.getRangeAt(0);
  range.deleteContents();
  range.insertNode(textNode);
  range.collapse(false);
  
  el.dispatchEvent(new InputEvent('input', {
    inputType: 'insertText',
    data: ch,
    bubbles: true,
    cancelable: true
  }));
  
  el.dispatchEvent(new KeyboardEvent('keyup', { key: ch, bubbles: true }));
}
```

**原理**：最接近真实人类输入的完整事件序列。

---

### [ ] 方案5：`innerText` 设置 + 完整事件链

直接用 `innerText` 设置内容，然后触发完整事件链。

```javascript
el.focus();
el.innerText = message;
el.dispatchEvent(new Event('input', { bubbles: true }));
el.dispatchEvent(new InputEvent('input', {
  inputType: 'insertText',
  data: message,
  bubbles: true,
  cancelable: true
}));
// 额外触发 React 合成事件
var nativeInputValueSetter = Object.getOwnPropertyDescriptor(
  window.HTMLDivElement.prototype, 'innerText'  // 或 'textContent'
);
// 一些 React 版本监听的是 value setter
```

**原理**：绕过 React 的合成事件直接操作。

---

### [ ] 方案6：直接操作 React 内部状态（侵入式）

通过 React fiber 或 internals 直接调用 Slate 的 `onChange`。

```javascript
// 方法 A: 通过 React fiber
var fiberKey = Object.keys(el).find(k => k.startsWith('__reactFiber'));
if (fiberKey) {
  var fiber = el[fiberKey];
  // 遍历 fiber 树找到 stateNode
}

// 方法 B: 通过 __reactProps
var propsKey = Object.keys(el).find(k => k.startsWith('__reactProps'));
if (propsKey) {
  var props = el[propsKey];
  if (props.onChange) {
    // 构造 Slate Value 对象
  }
}
```

**原理**：直接操作 React 组件内部状态。**风险**：非常脆弱，依赖 React/Slate 内部实现细节。

---

### [ ] 方案7：强制点击提交按钮 + 兜底策略

即使 Slate 内部状态为空，也尝试强行激活并点击发送按钮。

```javascript
// 硬点击按钮
var btn = document.querySelector('button[aria-label="发送消息"]');
btn.disabled = false;
btn.removeAttribute('aria-disabled');
_simulateClick(btn);
btn.click();

// 或者通过 innerHTML 注入后直接回车
el.innerHTML = message;
var enter = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', bubbles: true });
el.dispatchEvent(enter);
```

---

### [ ] 方案8：window 级事件分发

Slate.js 在某些版本中在 `document` 或 `window` 级别监听 `beforeinput`。尝试在 `document` 上直接分发事件。

---

### [ ] 方案9：使用 `ClipboardEvent` + `paste`（更真实的粘贴模拟）

```javascript
el.focus();
el.innerHTML = '';
var clipboardData = new DataTransfer();
clipboardData.setData('text/plain', message);

el.dispatchEvent(new ClipboardEvent('beforepaste', {
  clipboardData: clipboardData,
  bubbles: true,
  cancelable: true
}));

el.dispatchEvent(new ClipboardEvent('paste', {
  clipboardData: clipboardData,
  bubbles: true,
  cancelable: true
}));

// DOM 更新
var textNode = document.createTextNode(message);
el.appendChild(textNode);
el.dispatchEvent(new InputEvent('input', {
  inputType: 'insertFromPaste',
  data: message,
  bubbles: true,
  cancelable: true
}));
```

---

## 测试结果记录

| 方案 | 状态 | 结果 |
|------|------|------|
| 方案1 (execCommand) | ❌ 已知失败 | 文本可见但发送按钮未激活 |
| 方案2 (beforeinput + DOM) | ❌ 失败 | 发送按钮未激活 |
| 方案3 (粘贴模拟) | ❌ 失败 | 发送按钮未激活 |
| **方案7+ (execCommand + 强制点击按钮)** | **⏳ 当前尝试中** | 强制移除按钮disabled属性 + 多样选择器 + 回车 + 延时重试 |

> ✅ = 成功 | ❌ = 失败 | ⏳ = 待测试
