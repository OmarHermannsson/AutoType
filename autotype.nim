#[

A small utility that will type the provided text in the selected window.
Useful for cases where you cannot paste, such as a iDrac/ILO/VMware remote console window
 
Copyright © 2022 Ómar Hermannsson

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the “Software”), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]#

import std/strformat
import std/unicode
import std/tables
import std/os
import wNim/[wApp, wFrame, wPanel, wStaticText, wTextCtrl, wButton, wMenuBar, wMessageDialog, wIcon]
import winim/lean
import winim/inc/[windef, winbase, winuser]

# For the binary icon
{.link: "resource/icon.res".}

let app = App()
let mStyle = wCaption or wMinimizeBox or wSystemMenu or wStayOnTop
let frame = Frame(title="Type In Window - for when copy/paste is not an option", size=(500,70), pos=(10,90), style=mStyle)
frame.icon = Icon("",0) # Use the binary icon for the frame
let panel = Panel(frame)
let label = StaticText(panel, label="Text value to type:")
let input = TextCtrl(panel, style=wTePassword)
let button = Button(panel, label="Select &window...")

type 
  WindowObj = object
    hwnd: HWND
    className: string
    rect: RECT

let autoMenu = Menu()
var autoKey: Table[string, WindowObj]

proc layout() =
  panel.autolayout """
    H:|[line:-[label]-[input]-[button(==120)]]-|
    V:|-[line]-|
  """

proc sendKey(vkey:SHORT, sendKeyUp:bool) =
  var inp: INPUT
  inp.type = INPUT_KEYBOARD
  inp.ki.wVk = 0
  inp.ki.dwExtraInfo = GetMessageExtraInfo()
  inp.ki.time = 0
  if sendKeyUp:
    inp.ki.dwFlags = KEYEVENTF_KEYUP
  inp.ki.dwFlags = inp.ki.dwFlags or KEYEVENTF_SCANCODE
  inp.ki.wScan = uint16(MapVirtualKeyA(vkey, MAPVK_VK_TO_VSC_EX))
  SendInput(1, inp, sizeof(inp))

proc sendKey(rune: Rune, sendKeyUp:bool = false) =
  var inp: INPUT
  inp.type = INPUT_KEYBOARD
  inp.ki.wVk = 0
  inp.ki.dwExtraInfo = GetMessageExtraInfo()
  inp.ki.time = 0

  let vkey:SHORT = VkKeyScanEx(cast[WCHAR](rune), GetKeyboardLayout(0))
  #echo fmt"{rune}: {LOBYTE(vkey)}-{HIBYTE(vkey)} {uint16(rune)} {ord(rune)}"

  if (HIBYTE(vkey) and 1) == 1:
    sendKey(VK_SHIFT, false)
  if (HIBYTE(vkey) and 2) == 2:
    sendKey(VK_CONTROL, false)
  if (HIBYTE(vkey) and 4) == 4:
    sendKey(VK_MENU, false)

  if vkey == -1:
    # No virtual key found, we'll send unicode instead
    inp.ki.dwFlags = inp.ki.dwFlags or KEYEVENTF_UNICODE
    inp.ki.wScan = uint16(rune)
  else:
    inp.ki.dwFlags = inp.ki.dwFlags or KEYEVENTF_SCANCODE  
    let scanCode = MapVirtualKeyA(UINT(LOBYTE(vkey)), MAPVK_VK_TO_VSC_EX)
    inp.ki.wScan = uint16(scanCode)
  
  SendInput(1, inp, sizeof(inp))
  
  if (HIBYTE(vkey) and 1) == 1:
    sendKey(VK_SHIFT, true)
  if (HIBYTE(vkey) and 2) == 2:
    sendKey(VK_CONTROL, true)
  if (HIBYTE(vkey) and 4) == 4:
    sendKey(VK_MENU, true)
  
  inp.ki.dwFlags = inp.ki.dwFlags or KEYEVENTF_KEYUP
  SendInput(1, inp, sizeof(inp))

# Handles when menu item is selected from the list of windows
frame.wEvent_Menu  do (event: wEvent):
  let mText = event.getMenuItem().mText
  let hwnd = autoKey[mText].hwnd
  let class = autoKey[mText].className
  let rect:RECT = autoKey[mText].rect
  let inputText = input.value
  input.value = ""
  if class == "VMPlayerFrame":
    echo "VMPlayerFrame"
    let width = rect.right - rect.left
    let height = rect.bottom - rect.top
    let mx:int = int(width/2) + rect.left
    let my:int = int(height/2) + rect.top
    let dx = int((mx * 65536) / GetSystemMetrics(SM_CXSCREEN))
    let dy = int((my * 65536) / GetSystemMetrics(SM_CYSCREEN))
    var minp: INPUT
    minp.type = INPUT_MOUSE
    minp.mi.dX = dx
    minp.mi.dY = dy
    echo fmt"X: {dx} / Y: {dy} - {rect}"
    minp.mi.mouseData = 0
    minp.mi.dwFlags = MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE
    SendInput(1, minp, sizeof(minp))    
    #frame.minimize()
    ShowWindow(hwnd, SW_RESTORE)
    BringWindowToTop(hwnd)
    SetForegroundWindow(hwnd)    
    minp.mi.time = 0
    minp.mi.dwExtraInfo = GetMessageExtraInfo()
    minp.mi.dwFlags = MOUSEEVENTF_LEFTDOWN 
    SendInput(1, minp, sizeof(minp))
    minp.mi.dwFlags = MOUSEEVENTF_LEFTUP 
    SendInput(1, minp, sizeof(minp))
  else:
    #frame.minimize()
    ShowWindow(hwnd, SW_RESTORE)
    BringWindowToTop(hwnd)
    SetForegroundWindow(hwnd)
  sleep(400)
  for chr in inputText.toRunes():
    sleep(12)
    sendKey(chr)

# Callback function for EnumWindows - called for each window enumerated
proc EnumWindowsHandler(hwnd: HWND, lparam: LPARAM): WINBOOL {.stdcall.} =
  let txtLength: int = GetWindowTextLength(hwnd)
  var wText: LPWSTR = cast[PWSTR](VirtualAlloc(cast[LPVOID](nil), cast[DWORD](txtLength+1), MEM_COMMIT, PAGE_READWRITE))
  var className: LPWSTR = cast[PWSTR](VirtualAlloc(cast[LPVOID](nil), cast[DWORD](256), MEM_COMMIT, PAGE_READWRITE))
  if cast[bool](IsWindowVisible(hwnd)) and txtLength > 0:    
    GetWindowText(hwnd, wText, txtLength+1)
    GetClassName(hwnd, className, 256);  
    var lprect: RECT
    GetWindowRect(hwnd, lprect)
    if $className in @["Windows.UI.Core.CoreWindow", "ApplicationFrameWindow", "Progman", "CabinetWClass"]:
      return true
    autoMenu.append(wIdAny, $wText)
    var wnd: WindowObj
    wnd.hwnd = hwnd
    wnd.className = $className
    wnd.rect = lprect
    autoKey[$wText] = wnd
    echo fmt"Window: {wText} - Class: {className}"
  VirtualFree(wText, cast[DWORD](txtLength+1), MEM_DECOMMIT)
  VirtualFree(wText, cast[DWORD](256), MEM_DECOMMIT)
  return  true

# Handle button click
button.wEvent_Button do (event: wEvent):
  var lparam: LPARAM
  autoMenu.removeAll()
  EnumWindows(EnumWindowsHandler, lparam)
  button.popupMenu(autoMenu)

layout()
frame.center() # Center frame window in screen
frame.show() # A frame is hidden on creation by default.

app.mainLoop()