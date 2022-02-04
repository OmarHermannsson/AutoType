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

let autoMenu = Menu()
var autoKey: Table[string, HWND]

proc layout() =
  panel.autolayout """
    H:|[line:-[label]-[input]-[button(==120)]]-|
    V:|-[line]-|
  """

# Handles when menu item is selected from the list of windows
frame.wEvent_Menu  do (event: wEvent):
  let mText = event.getMenuItem().mText
  let hwnd = autoKey[mText]
  let inputText = input.value
  input.value = ""
  SetForegroundWindow(hwnd)
  sleep(500)
  for chr in inputText.toRunes():
    var inp: INPUT
    inp.type = INPUT_KEYBOARD
    inp.ki.wVk = 0
    inp.ki.wScan = uint16(chr)
    inp.ki.dwFlags = KEYEVENTF_UNICODE
    var rtn:UINT = 0
    while rtn == 0:
      sleep(30)
      rtn = SendInput(1, inp, sizeof(inp))

# Callback function for EnumWindows - called for each window enumerated
proc EnumWindowsHandler(hwnd: HWND, lparam: LPARAM): WINBOOL {.stdcall.} =
  let txtLength: int = GetWindowTextLength(hwnd)
  var wText: LPWSTR = cast[PWSTR](VirtualAlloc(cast[LPVOID](nil), cast[DWORD](txtLength+1), MEM_COMMIT, PAGE_READWRITE))
  var className: LPWSTR = cast[PWSTR](VirtualAlloc(cast[LPVOID](nil), cast[DWORD](256), MEM_COMMIT, PAGE_READWRITE))
  if cast[bool](IsWindowVisible(hwnd)) and txtLength > 0:    
    GetWindowText(hwnd, wText, txtLength+1)
    GetClassName(hwnd, className, 256);  
    if $className in @["Windows.UI.Core.CoreWindow", "ApplicationFrameWindow", "Progman", "CabinetWClass"]:
      return true
    autoMenu.append(wIdAny, $wText)
    autoKey[$wText] = hwnd
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
#frame.center() # Center frame window in screen
frame.show() # A frame is hidden on creation by default.

app.mainLoop()