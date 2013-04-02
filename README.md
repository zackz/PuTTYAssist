PuTTY Assist
============

PuTTY Assist is auxiliary tools for [PuTTY](http://www.chiark.greenend.org.uk/~sgtatham/putty/)
based on [AutoIt](http://www.autoitscript.com/site/autoit/). Developed for people working on
windows platform and looking for extreme efficiency.

Getting Started
---------------

* Install [AutoIt(3.3.8+)](http://www.autoitscript.com/site/autoit/downloads/)
  * Or get `AutoIt.exe` and `Include` directory. Clean and minimized, it's preffered way to
run PuTTYAssist.
  * Or compile excutable file using `build.py`.
* Run PuTTYAssist.au3 and open some PuTTYs, and try some shortcut below
  * Use `ALT + 1` / `ALT + 2` ... and `CTRL + TAB` to switch
  * Use `ALT + F1` to open new PuTTY...
  * Use ```ALT + ` ``` to show last PuTTY

Features
--------

* Automatically find all running PuTTY windows, hide in taskbar, and maximize the window
* Use configurable shortcut to popup managed PuTTY windows, ```ALT + ` ```, `CTRL + TAB`, 
`ALT + [N]`, `CTRL + SHIFT + [N]`, `ALT + SHIFT + J/K/H/M/L`
* `CTRL + V` is available now
* Copy all text in PuTTY to text editor, convenient for copy, `CTRL + SHIFT + C`
* Create new PuTTY session, `ALT + F1`
* Duplicate current session, `CTRL + SHIFT + T`
* Popup PuTTY's context menu by keyboard
* Change PuTTY background color, `CTRL + F9/F10/F11/F12`
* Send key sequence to PuTTY window
  * Send customized key combination
  * Extract environment variables and settings out of box
  * Run simple script

Settings
--------

After first run, a configure file - **PuTTYAssist.ini** was auto generated in same directory.
All config with prefix `HotKey_` is a key combination: `! is ALT`, `+ is SHIFT`, `^ is CTRL`,
`# is WINKEY`, and [more...](http://www.autoitscript.com/autoit3/docs/functions/Send.htm)

*(Make sure to close PuTTYAssist first before making any changes)*

Hide PuTTY in taskbar, and maximize it automatically.

```ini
AUTOHIDE=1
AUTOMAXIMIZE=1
```

Initial state of main window. (Use ALT+` to show/hide this window when PuTTYAssist is running.)

```ini
HIDEGUI=0
```

Position and width of PuTTYAssist's window

```ini
WIDTH=280
POS_X=1370
POS_Y=50
```

Paste, `CTRL + V`

```ini
HotKey_Paste=^v
```

Copy all text to editor, `CTRL + SHIFT + C`

```ini
HotKey_Copy=^+c
NOTEPADPATH=Notepad.exe
```

Popup PuTTY session window, `ALT + F1`

```ini
HotKey_NewPutty_Global=!{F1}
PUTTYPATH=C:\putty\PUTTY.EXE
```

Duplicate session, `CTRL + SHIFT + T`

```ini
HotKey_DuplicateSession=^+t
```

PuTTY context menu

```ini
HotKey_Appskey={APPSKEY}
```

Change background color, `CTRL + F9/F10/F11/F12`

```ini
HotKey_BG_R=!{F9}
HotKey_BG_G=!{F10}
HotKey_BG_B=!{F11}
HotKey_BG_Clear=!{F12}
```

Popup last PuTTY window when focus is on anywhere, ```ALT + ` ```.
And it'll show/hide GUI dialog when PuTTY window already on foreground.

```ini
HotKey_SwitchToLastOne_Global=!`
```

Switch to last PuTTY window, `CTRL + TAB`

```ini
HotKey_SwitchToMost=^{TAB}
```

Switch to ...

```ini
; Next
HotKey_SwitchToNext=^+j
; Previous
HotKey_SwitchToPrev=^+k
; First
HotKey_Switch_H=^+h
; Middle
HotKey_Switch_M=^+m
; Last
HotKey_Switch_L=^+l
```

Switch to managed PuTTY window when focus is on PuTTYAssist or PuTTY windos, `ALT + [N]`

```ini
HotKey_SwitchTo_1=!1
HotKey_SwitchTo_2=!2
HotKey_SwitchTo_3=!3
HotKey_SwitchTo_4=!4
HotKey_SwitchTo_5=!5
HotKey_SwitchTo_6=!6
HotKey_SwitchTo_7=!7
HotKey_SwitchTo_8=!8
HotKey_SwitchTo_9=!9
```

Popup managed PuTTY window when focus is **not** on PuTTYAssist or PuTTY windos, `CTRL + SHIFT + [N]`

```ini
HotKey_SwitchTo_Global_1=^+1
HotKey_SwitchTo_Global_2=^+2
HotKey_SwitchTo_Global_3=^+3
HotKey_SwitchTo_Global_4=^+4
HotKey_SwitchTo_Global_5=^+5
HotKey_SwitchTo_Global_6=^+6
HotKey_SwitchTo_Global_7=^+7
HotKey_SwitchTo_Global_8=^+8
HotKey_SwitchTo_Global_9=^+9
```

Send key sequence to PuTTY window

```ini
; HotKey is ALT + SHIFT + 1
; Effect is clear screen and run ifconfig
KEYSEQ1_HOTKEY=!+1
KEYSEQ1_SEQUENCE=^lifconfig{ENTER}

; HotKey is ALT + SHIFT + 2
; This key sequence is for vim which add two options: number and hlsearch
KEYSEQ2_HOTKEY=!+2
KEYSEQ2_SEQUENCE=:set number hlsearch{ENTER}:color delek{ENTER}

; HotKey is ALT + SHIFT + 3
; This key sequence is for vim or less which highlight valid lines except comments.
; Original sequence is "/^[^#^;].*". But "^" is shortcut for "CTRL", so replaced with "{^}"
KEYSEQ3_HOTKEY=!+3
KEYSEQ3_SEQUENCE=/{^}[{^}{#}{^};].*{ENTER}

; HotKey is ALT + SHIFT + 4
; Automatically enter password
KEYSEQ4_HOTKEY=!+4
KEYSEQ4_SEQUENCE=1234567890{ENTER}

; HotKey is ALT + SHIFT + 5
; Run script
KEYSEQ5_HOTKEY=!+5
KEYSEQ5_SEQUENCE=. <(wget -qO- http://192.168.1.2/env.sh){ENTER}
```

Tips
----

* Drag list items in PuTTYAssist to change sequence, put frequently used PuTTY to
location 1/2/3 (ALT+1/ALT+2...)
* Use `ALT + F1` to create new PuTTY session. After displayed the PuTTY Configuration window, 
focus was on Saved Sessions list. So make stored session names with different initial letters, 
then press the letter to quickly locate it.
* PuTTYAssist has a system tray
  * Reset assist dialog location
  * Quit PuTTYAssist
* [Some tips about PuTTY](https://github.com/zackz/PuTTYAssist/wiki/PuTTY-Tips)
* [Use NaviAssist to enhance PuTTYAssist](https://github.com/zackz/NaviAssist/wiki/Use-NaviAssist-to-enhance-PuTTYAssist)
