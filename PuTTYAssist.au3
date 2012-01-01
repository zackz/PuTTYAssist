#cs ----------------------------------------------------------------------------

PuTTY Assist
https://github.com/zackz/PuTTYAssist

#ce ----------------------------------------------------------------------------

#include <Math.au3>
#Include <Misc.au3>
#include <Array.au3>
#include <Process.au3>
#include <WinAPI.au3>
#include <Timers.au3>
#Include <Clipboard.au3>
#include <Constants.au3>
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <ColorConstants.au3>
#Include <GuiImageList.au3>
#Include <GuiButton.au3>
#include <GuiEdit.au3>
#include <GuiListView.au3>
#include <ListViewConstants.au3>
#include <GUIListBox.au3>
#Include <GuiTreeView.au3>

Global Const $NAME = "PuTTY Assist"
Global Const $VERSION = "0.5.7"
Global Const $MAIN_TITLE = $NAME & " " & $VERSION
Global Const $PAGEURL = "https://github.com/zackz/PuTTYAssist"
Global Const $PATH_INI = "PuTTYAssist.ini"
Global Const $SECTION_NAME = "PROPERTIES"
Global Const $TITLE_PUTTYCONFIGBOX = "[CLASS:PuTTYConfigBox]"
Global Const $ASSIST_DEFAULT_HEIGHT = 100
Global Const $DEBUG_OUTPUT_BITS = 0 ; 0: no output, 1: console, 2: OutputDebugString

Global Const $CFGKEY_WIDTH = "WIDTH"
Global Const $CFGKEY_POS_X = "POS_X"
Global Const $CFGKEY_POS_Y = "POS_Y"
Global Const $CFGKEY_PUTTYPATH = "PUTTYPATH"
Global Const $CFGKEY_NOTEPADPATH = "NOTEPADPATH"
Global Const $CFGKEY_AUTOHIDE = "AUTOHIDE"
Global Const $CFGKEY_AUTOMAXIMIZE = "AUTOMAXIMIZE"
Global Const $CFGKEY_REFRESHTIME = "REFRESHTIME"

Global $g_hGUI
Global $g_hListView
Global $g_idListView
Global $g_idTrayNew
Global $g_idTrayReset
Global $g_idTrayHide
Global $g_idTrayAbout
Global $g_idTrayQuit
Global $g_wListProcOld
Global $g_oTaskbarList

Global $g_bShowingAbout = False
Global $g_nDragging = False
Global $g_bLeaving = False
Global $g_bRefreshing = False
Global $g_bSwitching = False
Global $g_bManuallyHideGUI = False
Global $g_iSwitch_AfterRefreshing = -1
Global $g_HideTaskbar_AfterRefreshing = 0
Global $g_WriteBackCFG_AfterRefreshing = 0
Global $g_avCFG[1][2] = [[0]]
Global $g_avData[1]
Global $g_avRecentQueue[1]

main()

Func main()
	If _Singleton($NAME, 1) = 0 Then
		; Popup last assist and open last putty
		If WinActivate($MAIN_TITLE) <> 0 Then
			Send("{ENTER}")
		EndIf
		Exit
	EndIf

	dbg("Enter main...")
	
	Opt("MustDeclareVars", 1)
	Opt("WinWaitDelay", 0)
	Opt("TrayMenuMode", 1)
	Opt("TrayOnEventMode", 1)
	If $DEBUG_OUTPUT_BITS <> 0 Then
		AutoItSetOption ("TrayIconDebug", 1)
	EndIf

	GUIRegisterMsg($WM_NOTIFY, "WM_NOTIFY")
	GUIRegisterMsg($WM_SIZE, "WM_SIZE")
	GUIRegisterMsg($WM_LBUTTONUP, "WM_LBUTTONUP")
	GUIRegisterMsg($WM_MOUSEMOVE, "WM_MOUSEMOVE")

	InitCFG()
	InitHotKey()
	InitTray()
	MainDlg()

	dbg("Leaving...")
EndFunc

Func InitCFG()
	Local $av = IniReadSection($PATH_INI, $SECTION_NAME)
	If UBound($av) > 0 Then
		$g_avCFG = $av
	EndIf
	CFGSetDefault($CFGKEY_WIDTH,         280)
	CFGSetDefault($CFGKEY_POS_X,         (@DesktopWidth - CFGGetInt($CFGKEY_WIDTH) - 30))
	CFGSetDefault($CFGKEY_POS_Y,         50)
	CFGSetDefault($CFGKEY_PUTTYPATH,     "")
	CFGSetDefault($CFGKEY_NOTEPADPATH,   "Notepad.exe") ; "SciTE.exe"
	CFGSetDefault($CFGKEY_AUTOHIDE,      1) ; Auto hide other PuTTY window's taskbar
	CFGSetDefault($CFGKEY_AUTOMAXIMIZE,  1) ; Auto maximize NEW PuTTY window
	CFGSetDefault($CFGKEY_REFRESHTIME,   150)
	CFGSetDefault("HOTKEY_NOTES",        "ALT[!], SHIFT[+], CTRL[^], WINKEY[#], Details in http://www.autoitscript.com/autoit3/docs/functions/Send.htm")
EndFunc

Func CFGKeyIndex($key)
	For $i = 1 To $g_avCFG[0][0]
		; Case insensitive
		If Not($key <> $g_avCFG[$i][0]) Then Return $i
	Next
	Return -1
EndFunc

Func CFGGet($key)
	Local $index = CFGKeyIndex($key)
	If $index >= 0 Then
		Return $g_avCFG[$index][1]
	Else
		dbg("!!!")
		Return 0
	EndIf
EndFunc

Func CFGGetInt($key)
	Return Int(CFGGet($key))
EndFunc

Func CFGGet2($key, $defaultvalue)
	CFGSetDefault($key, $defaultvalue)
	Return CFGGet($key)
EndFunc

Func CFGSetDefault($key, $defaultvalue)
	If CFGKeyIndex($key) < 0 Then
		CFGSet($key, $defaultvalue)
	EndIf
EndFunc

Func CFGSet($key, $value)
	Local $index = CFGKeyIndex($key)
	If $index < 0 Then
		; New key
		$index = $g_avCFG[0][0] + 1
		ReDim $g_avCFG[$index + 1][2]
		$g_avCFG[0][0] = $index
		$g_avCFG[$index][0] = $key
	ElseIf $value = $g_avCFG[$index][1] Then
		; Not changed
		Return
	EndIf
	$g_avCFG[$index][1] = $value
	; CFG changed, write back in MgrRefresh()
	$g_WriteBackCFG_AfterRefreshing = _Timer_Init()
EndFunc

Func CFGWriteBack()
	Local $t = _Timer_Init()
	IniWriteSection($PATH_INI, $SECTION_NAME, $g_avCFG)
	dbg("CFGWriteBack", _Timer_Diff($t))
EndFunc

Func InitHotKey()
#comments-start
	http://www.autoitscript.com/autoit3/docs/functions/Send.htm
	
	'!'
	This tells AutoIt to send an ALT keystroke, therefore Send("This is text!a") would send the keys "This is text" and then press "ALT+a".
	N.B. Some programs are very choosy about capital letters and ALT keys, i.e. "!A" is different to "!a". The first says ALT+SHIFT+A, the second is ALT+a. If in doubt, use lowercase!

	'+'
	This tells AutoIt to send a SHIFT keystroke, therefore Send("Hell+o") would send the text "HellO". Send("!+a") would send "ALT+SHIFT+a".

	'^'
	This tells AutoIt to send a CONTROL keystroke, therefore Send("^!a") would send "CTRL+ALT+a".
	N.B. Some programs are very choosy about capital letters and CTRL keys, i.e. "^A" is different to "^a". The first says CTRL+SHIFT+A, the second is CTRL+a. If in doubt, use lowercase!

	'#'
	The hash now sends a Windows keystroke; therefore, Send("#r") would send Win+r which launches the Run dialog box.
#comments-end

	; Show/Hide assist window.
	HotKeySet(CFGGet2("HotKey_GUI_Global",              "^`"),         "HotKey_GUI_Global")
	; Show PuTTY's config dialog and focus on session list.
	; Tips: Make stored session names with different initial letters, press the letter to quickly focus on session.
	HotKeySet(CFGGet2("HotKey_NewPutty_Global",         "!{F1}"),      "HotKey_NewPutty_Global")

	HotKeySet(CFGGet2("HotKey_SwitchToMost",            "^{TAB}"),     "HotKey_SwitchToMost")
	; Recent queue is not fully used. "Switch to last one" just works well.
;~ 	HotKeySet("^+{TAB}",     "HotKey_SwitchToLeast")
	HotKeySet(CFGGet2("HotKey_SwitchToNext",            "^+j"),        "HotKey_SwitchToNext") ; "^+{DOWN}"
	HotKeySet(CFGGet2("HotKey_SwitchToPrev",            "^+k"),        "HotKey_SwitchToPrev") ; "^+{UP}"
	HotKeySet(CFGGet2("HotKey_Switch_H",                "^+h"),        "HotKey_Switch_H")
	HotKeySet(CFGGet2("HotKey_Switch_M",                "^+m"),        "HotKey_Switch_M")
	HotKeySet(CFGGet2("HotKey_Switch_L",                "^+l"),        "HotKey_Switch_L")

	HotKeySet(CFGGet2("HotKey_DuplicateSession",        "^+t"),        "HotKey_DuplicateSession")
	HotKeySet(CFGGet2("HotKey_Copy",                    "^+c"),        "HotKey_Copy")
	HotKeySet(CFGGet2("HotKey_Paste",                   "^v"),         "HotKey_Paste")
	HotKeySet(CFGGet2("HotKey_Appskey",                 "{APPSKEY}"),  "HotKey_Appskey")
	HotKeySet(CFGGet2("HotKey_BG_R",                    "!{F9}"),      "HotKey_BG_R")
	HotKeySet(CFGGet2("HotKey_BG_G",                    "!{F10}"),     "HotKey_BG_G")
	HotKeySet(CFGGet2("HotKey_BG_B",                    "!{F11}"),     "HotKey_BG_B")
	HotKeySet(CFGGet2("HotKey_BG_Clear",                "!{F12}"),     "HotKey_BG_Clear")

	HotKeySet(CFGGet2("HotKey_SwitchTo_1",              "!1"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_2",              "!2"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_3",              "!3"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_4",              "!4"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_5",              "!5"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_6",              "!6"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_7",              "!7"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_8",              "!8"),         "HotKey_SwitchTo")
	HotKeySet(CFGGet2("HotKey_SwitchTo_9",              "!9"),         "HotKey_SwitchTo")

	HotKeySet(CFGGet2("HotKey_SwitchToLastOne_Global",  "!`"),         "HotKey_SwitchToLastOne_Global") ; "^+`"
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_1",       "^+1"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_2",       "^+2"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_3",       "^+3"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_4",       "^+4"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_5",       "^+5"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_6",       "^+6"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_7",       "^+7"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_8",       "^+8"),        "HotKey_SwitchTo_Global")
	HotKeySet(CFGGet2("HotKey_SwitchTo_Global_9",       "^+9"),        "HotKey_SwitchTo_Global")
EndFunc

Func InitTray()
	TraySetOnEvent($TRAY_EVENT_PRIMARYUP, "MgrSwitchToCurrent")
	TraySetClick(16)

	$g_idTrayNew = TrayCreateItem("Open new PuTTY...")
	TrayItemSetOnEvent(-1, "Tray_EventHandler")
	$g_idTrayReset = TrayCreateItem("Reset assist dialog location")
	TrayItemSetOnEvent(-1, "Tray_EventHandler")
	TrayCreateItem("")

	$g_idTrayHide = TrayCreateItem("Hide assist dialog")
	TrayItemSetOnEvent(-1, "Tray_EventHandler")
	TrayCreateItem("")

;~ 	$g_idTrayAbout = TrayCreateItem("About...")
;~ 	TrayItemSetOnEvent(-1, "Tray_EventHandler")
	$g_idTrayQuit = TrayCreateItem("Quit")
	TrayItemSetOnEvent(-1, "Tray_EventHandler")
EndFunc

Func Tray_EventHandler()
	dbg("Tray_EventHandler()", @TRAY_ID)
	dbg($g_idTrayNew, $g_idTrayHide, $g_idTrayAbout, $g_idTrayQuit)
	Switch @TRAY_ID
		Case $g_idTrayNew
			HotKey_NewPutty_Global()
			TrayItemSetState($g_idTrayNew, $TRAY_UNCHECKED)

		Case $g_idTrayHide
			HotKey_Func_GUI($g_bManuallyHideGUI)
			$g_bManuallyHideGUI = Not($g_bManuallyHideGUI)

		Case $g_idTrayReset
			CFGSet($CFGKEY_WIDTH, 280)
			CFGSet($CFGKEY_POS_X, @DesktopWidth - CFGGetInt($CFGKEY_WIDTH) - 30)
			CFGSet($CFGKEY_POS_Y, 50)
			Local $pos = WinGetPos($g_hGUI)
			Local $newHeight = _Iif($pos <> 0, $pos[3], $ASSIST_DEFAULT_HEIGHT)
			WinMove($g_hGUI, "", CFGGetInt($CFGKEY_POS_X), CFGGetInt($CFGKEY_POS_Y), CFGGetInt($CFGKEY_WIDTH), $newHeight)
			HotKey_Func_GUI(True)
			TrayItemSetState($g_idTrayReset, $TRAY_UNCHECKED)

		Case $g_idTrayAbout
			ShowAbout()
			TrayItemSetState($g_idTrayAbout, $TRAY_UNCHECKED)

		Case $g_idTrayQuit
			$g_bLeaving = True
			WinClose($g_hGUI)
	EndSwitch
EndFunc

Func MainDlg()
	$g_hGUI = GUICreate($MAIN_TITLE, CFGGetInt($CFGKEY_WIDTH), $ASSIST_DEFAULT_HEIGHT, Default, Default, $WS_SIZEBOX)
	Local $aiGUISize = WinGetClientSize($g_hGUI)

	; Crashed in win7 when resizing dialog. It's seems that scroll bar in list and replaced
	; winproc doesn't work well together, remove either of them will cause no crash.
	; So create list with $LVS_NOSCROLL.
	Local $style = BitOR($LVS_SHOWSELALWAYS, $LVS_SINGLESEL, $LVS_NOCOLUMNHEADER, $LVS_NOSCROLL)
	$g_idListView = GUICtrlCreateListView("", 0, 0, $aiGUISize[0], $aiGUISize[1] - 20, $style)
	$g_hListView = GUICtrlGetHandle($g_idListView)
	Local $hHelp = GUICtrlCreateButton("Show Hotkeys", 0, $aiGUISize[1] - 20, $aiGUISize[0], 20)
	GUICtrlSetResizing($g_idListView, $GUI_DOCKBORDERS)
	GUICtrlSetResizing($hHelp, BitOR($GUI_DOCKHEIGHT, $GUI_DOCKLEFT, $GUI_DOCKBOTTOM))

	$style = BitOR($LVS_EX_GRIDLINES, $LVS_EX_FULLROWSELECT, $WS_EX_CLIENTEDGE, $LVS_EX_BORDERSELECT)
	_GUICtrlListView_SetExtendedListViewStyle($g_hListView, $style)
	_GUICtrlListView_SetBkColor($g_hListView, $CLR_MONEYGREEN)
	_GUICtrlListView_SetTextColor($g_hListView, $CLR_BLACK)
	_GUICtrlListView_SetTextBkColor($g_hListView, $CLR_MONEYGREEN)
	_GUICtrlListView_SetOutlineColor($g_hListView, $CLR_BLACK)
	_GUICtrlListView_AddColumn($g_hListView, "ColumnOne", CFGGetInt($CFGKEY_WIDTH) - 23)

	; Reciving keyboard messages in listview
	Local $wProcHandle = DllCallbackRegister("ListWindowProc", "int", "hwnd;uint;wparam;lparam")
	$g_wListProcOld = _WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, DllCallbackGetPtr($wProcHandle))

	Local Const $sCLSID_TaskbarList = "{56FDF344-FD6D-11D0-958A-006097C9A090}"
	Local Const $sIID_ITaskbarList = "{56FDF342-FD6D-11D0-958A-006097C9A090}"
	Local Const $sTagITaskbarList = "HrInit hresult(); AddTab hresult(hwnd); DeleteTab hresult(hwnd); ActivateTab hresult(hwnd); SetActiveAlt hresult(hwnd);"
	$g_oTaskbarList = ObjCreateInterface($sCLSID_TaskbarList, $sIID_ITaskbarList, $sTagITaskbarList)
	$g_oTaskbarList.HrInit()

	Local $idTimer = _Timer_SetTimer($g_hGUI, CFGGetInt($CFGKEY_REFRESHTIME), "Timer_Refresh")
	WinMove($g_hGUI, "", CFGGetInt($CFGKEY_POS_X), CFGGetInt($CFGKEY_POS_Y), CFGGetInt($CFGKEY_WIDTH), $ASSIST_DEFAULT_HEIGHT)
	WinSetOnTop($g_hGUI, "", 1)

	MgrGUIShow()
	MgrRefresh()
	GUISetState(@SW_SHOW, $g_hGUI)
	MgrSwitchTo(0)

	dbg("Main loop start...")
	While 1
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				; http://www.autoitscript.com/forum/topic/121154-winclose-will-not-kill-another-running-autoit-script/
				; http://www.autoitscript.com/forum/topic/7823-how-to-stop-esc-from-sending-gui-event-close/
				; WinClose and WinKill isn't working. Use "$g_bLeaving" to determine whether to quit and ask before quiting.
				; Opt("GUICloseOnESC", 0)
				Local $bQuit = False
				If $g_bLeaving Then 
					$bQuit = True
				Else
					Local $ret = MsgBox(1, $NAME, "Close " & $NAME & "?")
					If $ret = 1 Then $bQuit = True
				EndIf
				If $bQuit Then
					_Timer_KillTimer($g_hGUI, $idTimer)
					If CFGGetInt($CFGKEY_AUTOHIDE) Then
						For $i = 0 To DataGetLength() - 1
							$g_oTaskbarList.AddTab(DataGetHandle($i))
						Next
					EndIf
					ExitLoop
				EndIf
			Case $hHelp
				ShowAbout()
		EndSwitch
	WEnd

	_WinAPI_SetWindowLong($g_hListView, $GWL_WNDPROC, $g_wListProcOld)
	DllCallbackFree($wProcHandle)
	GUIDelete($g_hGUI)
EndFunc   ;==>MainDlg

Func ShowAbout()
	Local $text = _
			"by Zack Zhou <zackzhh@gmail.com>" & @CRLF & @CRLF & _
			"Hotkeys:" & @CRLF & _
			"* ALT+F1             Open new PuTTY" & @CRLF & _
			"  ALT+F9/F10/F11/F12 Change current PuTTY's background color to red/green/blue/black" & @CRLF & _
			"* ALT+`              Open last PuTTY window" & @CRLF & _
			"* CTRL+`             Show/Hide assist dialog" & @CRLF & _
			"  CTRL+SHITF+T       Duplicate session" & @CRLF & _
			"  CTRL+SHITF+C       Open a notepad show all text in current PuTTY (easy to copy)" & @CRLF & _
			"  CTRL+V             Paste" & @CRLF & _
			@CRLF & _
			"  CTRL+TAB           Switch to last PuTTY window" & @CRLF & _
			"  ALT+1, ALT+2, ..., ALT+[N]" & @CRLF & _
			"                     Switch to specified PuTTY window by N (Only works on PuTTY windows)" & @CRLF & _
			"* CTRL+SHIFT+[N]     Same to ALT+[N] but works anywhere" & @CRLF & _
			"  CTRL+SHITF+[J/K]   Switch PuTTY windows sequentially" & @CRLF & _
			"  CTRL+SHITF+[H/M/L] Switch to first/middle/last PuTTY window" & @CRLF & _
			"  ('*' means global keys which are valid on any window)" & @CRLF & _
			@CRLF & _
			"PuTTY and AutoIt are both great!!"
	$g_bShowingAbout = True
	If $g_hGUI Then WinSetState($g_hGUI, "", @SW_DISABLE)

	Local $iTextLeft = 9
	Local $iTitleHeight = 35
	Local $hAbout = GUICreate("About Assist", 550, 363, Default, Default, BitOR($WS_SIZEBOX, 0), 0, $g_hGUI)
	Local $aiGUISize = WinGetClientSize($hAbout)
	Local $hEdit = GUICtrlCreateEdit($text, $iTextLeft, $iTitleHeight + 8, $aiGUISize[0], $aiGUISize[1] - $iTitleHeight - 60, BitOR($ES_MULTILINE, $ES_READONLY), $WS_EX_TRANSPARENT)
	Local $hLine = GUICtrlCreateLabel("", 0, $aiGUISize[1] - 42, $aiGUISize[0], 2, 0x50000010)
	Local $hOK = GUICtrlCreateButton("&OK", $aiGUISize[0] - 90, $aiGUISize[1] - 32, 80)
	Local $hPage = GUICtrlCreateButton("&Visit " & $NAME & " github page", $aiGUISize[0] - 320, $aiGUISize[1] - 32, 220)
	GUISetFont(22, 800, 0, "Times New Roman")
	Local $hTitleText = GUICtrlCreateLabel($MAIN_TITLE, $iTextLeft, 8, $aiGUISize[0], $iTitleHeight)
	GUICtrlSetColor($hTitleText, 0x000000)

	GUICtrlSetResizing($hEdit, $GUI_DOCKBORDERS)
	GUICtrlSetResizing($hLine, $GUI_DOCKBOTTOM)
	GUICtrlSetResizing($hOK, BitOR($GUI_DOCKSIZE, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))
	GUICtrlSetResizing($hPage, BitOR($GUI_DOCKSIZE, $GUI_DOCKRIGHT, $GUI_DOCKBOTTOM))
	GUICtrlSetState($hOK, $GUI_DEFBUTTON)
	GUISetState(@SW_SHOW, $hAbout)
	While 1
		Switch GUIGetMsg()
			Case $hPage
				Run(@ComSpec & ' /c start "" "' & $PAGEURL & '"', "", @SW_HIDE)
			Case $GUI_EVENT_CLOSE, $hOK
				ExitLoop
		EndSwitch
	WEnd
	GUIDelete($hAbout)

	If $g_hGUI Then
		WinSetState($g_hGUI, "", @SW_ENABLE)
		WinActivate($g_hGUI)
	EndIf
	$g_bShowingAbout = False
EndFunc

Func ListWindowProc($hWnd, $Msg, $wParam, $lParam)
	; Use up and down key or J/K/H/M/L iterator items in listview.
	; http://www.autoitscript.com/forum/topic/83621-trapping-nm-return-in-a-listview-via-wm-notify/
	; http://msdn.microsoft.com/en-us/library/windows/desktop/dd375731%28v=vs.85%29.aspx
	Local Const $VK_RETURN = 0x0D
	Local Const $VK_UP = 0x26
	Local Const $VK_DOWN = 0x28
	Local Const $VK_H = 0x48
	Local Const $VK_I = 0x49
	Local Const $VK_J = 0x4A
	Local Const $VK_K = 0x4B
	Local Const $VK_L = 0x4C
	Local Const $VK_M = 0x4D
	Switch $hWnd
		Case $g_hListView
			Switch $Msg
				Case $WM_GETDLGCODE
					Switch $wParam
						Case $VK_RETURN
							dbg("Enter key is pressed")
							MgrSwitchToCurrent()
							Return 0
					EndSwitch
				Case $WM_KEYDOWN
					Local $next = -1
					Local $index = _GUICtrlListView_GetNextItem($g_hListView)
					Switch $wParam
						Case 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39
							MgrSwitchTo($wParam - 0x31)
						Case $VK_K, $VK_UP
							$next = Mod($index - 1 + DataGetLength(), DataGetLength())
						Case $VK_J, $VK_DOWN
							$next = Mod($index + 1 + DataGetLength(), DataGetLength())
						Case $VK_H
							$next = 0
						Case $VK_L
							$next = DataGetLength() - 1
						Case $VK_M
							$next = Int((DataGetLength() - 1) / 2)
					EndSwitch
					If $next >= 0 Then
						_GUICtrlListView_SetItemState($g_hListView, $next, $LVIS_FOCUSED + $LVIS_SELECTED, $LVIS_FOCUSED + $LVIS_SELECTED)
						Return 0
					EndIf
				Case $WM_CHAR
					; Avoid beep
					Return 0
			EndSwitch
	EndSwitch
	Return _WinAPI_CallWindowProc($g_wListProcOld, $hWnd, $Msg, $wParam, $lParam)
EndFunc

Func WM_NOTIFY($hWnd, $iMsg, $iwParam, $ilParam)
	Local $hWndFrom, $iIDFrom, $iCode, $tNMHDR, $tInfo
	$tNMHDR = DllStructCreate($tagNMHDR, $ilParam)
	$hWndFrom = HWnd(DllStructGetData($tNMHDR, "hWndFrom"))
	$iIDFrom = DllStructGetData($tNMHDR, "IDFrom")
	$iCode = DllStructGetData($tNMHDR, "Code")
	Switch $hWndFrom
		Case $g_hListView
			Switch $iCode
				Case $NM_CLICK ; Sent by a list-view control when the user clicks an item with the left mouse button
					$tInfo = DllStructCreate($tagNMITEMACTIVATE, $ilParam)
					dbg("$NM_CLICK" & @LF & "--> hWndFrom:" & @TAB & $hWndFrom & @LF & _
							"-->IDFrom:" & @TAB & $iIDFrom & @LF & _
							"-->Code:" & @TAB & $iCode & @LF & _
							"-->Index:" & @TAB & DllStructGetData($tInfo, "Index") & @LF & _
							"-->SubItem:" & @TAB & DllStructGetData($tInfo, "SubItem") & @LF & _
							"-->NewState:" & @TAB & DllStructGetData($tInfo, "NewState") & @LF & _
							"-->OldState:" & @TAB & DllStructGetData($tInfo, "OldState") & @LF & _
							"-->Changed:" & @TAB & DllStructGetData($tInfo, "Changed") & @LF & _
							"-->ActionX:" & @TAB & DllStructGetData($tInfo, "ActionX") & @LF & _
							"-->ActionY:" & @TAB & DllStructGetData($tInfo, "ActionY") & @LF & _
							"-->lParam:" & @TAB & DllStructGetData($tInfo, "lParam") & @LF & _
							"-->KeyFlags:" & @TAB & DllStructGetData($tInfo, "KeyFlags"))
					Local $index = DllStructGetData($tInfo, "Index")
					If $index >= 0 Then
						MgrSwitchTo($index)
					EndIf
				Case $LVN_BEGINDRAG
					$g_nDragging = MgrGetCurrent()
					If @OSVersion = "WIN_7" Then
						; Not working well in XP
						Local $hDragImageList = _GUICtrlListView_CreateDragImage($g_hListView, $g_nDragging)
						_GUIImageList_BeginDrag($hDragImageList[0], 0, 0, 0)
					EndIf
			EndSwitch
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc

Func WM_SIZE($hWndGUI, $MsgID, $wParam, $lParam)
	If $hWndGUI <> $g_hGUI Then Return $GUI_RUNDEFMSG
	Local $pos = WinGetPos($g_hGUI)
	If CFGGetInt($CFGKEY_WIDTH) <> $pos[2] Then
		CFGSet($CFGKEY_WIDTH, $pos[2])
		_GUICtrlListView_SetColumnWidth($g_hListView, 0, CFGGetInt($CFGKEY_WIDTH) - 23)
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc

Func WM_MOUSEMOVE($hWndGUI, $MsgID, $wParam, $lParam)
	If $g_nDragging < 0 Then Return
	Local $res = _GUICtrlListView_HitTest($g_hListView)
	If $res[0] >= 0 Then
		_GUICtrlListView_SetItemState($g_hListView, $res[0], $LVIS_FOCUSED + $LVIS_SELECTED, $LVIS_FOCUSED + $LVIS_SELECTED)
	EndIf
	Return $GUI_RUNDEFMSG
EndFunc

Func WM_LBUTTONUP($hWndGUI, $MsgID, $wParam, $lParam)
	If $g_nDragging < 0 Then Return
	Local $src = $g_nDragging
	Local $desc = -1
	$g_nDragging = -1

	Local $res = _GUICtrlListView_HitTest($g_hListView)
	If $res[0] >= 0 Or $res[1] Then
		; [0] - Zero based index of the item at the specified position, or -1 
		; [1] - If True, position is in control's client window but not on an item 
		$desc = _GUICtrlListView_GetNextItem($g_hListView)
	EndIf
	If $src < 0 Or $desc < 0 Or $src = $desc Then Return

	; Dummy message for drawing first
	_SendMessage($hWndGUI, $MsgID, $wParam, $lParam)

	; Update list
	DataMove($src, $desc)
	ListUpdate($g_hListView, $g_avData)

	Return $GUI_RUNDEFMSG
EndFunc

Func Timer_Refresh($hWnd, $Msg, $iIDTimer, $dwTime)
	Local $pos = WinGetPos($g_hGUI)
	If $pos <> 0 Then
		; Update pos x/y
		CFGSet($CFGKEY_POS_X, $pos[0])
		CFGSet($CFGKEY_POS_Y, $pos[1])
	EndIf
	MgrRefresh()
EndFunc

Func HotKey_Func_PassAlong($key, $func)
	dbg("HotKey_Func_PassAlong()", $key, $func)
	HotKeySet($key)
	Send($key)
	HotKeySet($key, $func)
EndFunc

Func HotKey_NewPutty_Global()
	If Not(CFGGet($CFGKEY_PUTTYPATH)) Then
		MsgBox(0, "Error open new PuTTY!", "Can't locate PuTTY path. Please run PuTTY at least once!")
		Return
	EndIf
	If WinExists($TITLE_PUTTYCONFIGBOX) Then
		WinActivate($TITLE_PUTTYCONFIGBOX)
		Return
	EndIf
	If Run(CFGGet($CFGKEY_PUTTYPATH)) = 0 Then
		CFGSet($CFGKEY_PUTTYPATH, "")
		Return
	EndIf

	; Avoid new config dialog being covered by putty window which activated in MgrRefresh().
	$g_bRefreshing = True

	; Find the stored session ListBox and set focus on it
	Local $handle = WinWaitActive($TITLE_PUTTYCONFIGBOX, "", 1)
	Local $hListBox = GetChildWindow($handle, "ListBox")
	If $hListBox <> 0 Then
		ControlFocus($g_hGUI, 0, $hListBox)
		_SendMessage($hListBox, $LB_SETCURSEL, 0, 0)
	EndIf

	; Avoid losing focus problem.
	; Sometimes putty config dialog wasn't active after pressing "CTRL+`" and "CTRL+F1".
	WinActivate($handle)

	$g_bRefreshing = False
EndFunc

;~ #define IDM_SHOWLOG   0x0010
;~ #define IDM_NEWSESS   0x0020
;~ #define IDM_DUPSESS   0x0030
;~ #define IDM_RESTART   0x0040
;~ #define IDM_RECONF    0x0050
;~ #define IDM_CLRSB     0x0060
;~ #define IDM_RESET     0x0070
;~ #define IDM_HELP      0x0140
;~ #define IDM_ABOUT     0x0150
;~ #define IDM_SAVEDSESS 0x0160
;~ #define IDM_COPYALL   0x0170
;~ #define IDM_FULLSCREEN	0x0180
;~ #define IDM_PASTE     0x0190
;~ #define IDM_SPECIALSEP 0x0200

Func HotKey_DuplicateSession()
	Local $index = MgrGetActive()
	If $index >= 0 Then
		_SendMessage(DataGetHandle($index), $WM_SYSCOMMAND, 0x0030, 0x0)
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, "HotKey_DuplicateSession")
	EndIf
EndFunc

Func HotKey_Paste()
	Local $index = MgrGetActive()
	If $index >= 0 Then
		_SendMessage(DataGetHandle($index), $WM_SYSCOMMAND, 0x0190, 0x0)
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, "HotKey_Paste")
	EndIf
EndFunc

Func HotKey_Copy()
	Local $index = MgrGetActive()
	If $index >= 0 Then
		; Copy all to clipboard
		_SendMessage(DataGetHandle($index), $WM_SYSCOMMAND, 0x0170, 0x0)

		; Run notepad or other editor
		Local $pid = Run(CFGGet($CFGKEY_NOTEPADPATH))
		dbg("HotKey_Copy(), run", $pid, CFGGet($CFGKEY_NOTEPADPATH))
		If $pid = 0 And CFGGet($CFGKEY_NOTEPADPATH) <> "Notepad.exe" Then
			; Bad notepad path, retry with notepad
			$pid = Run("Notepad.exe")
			dbg("HotKey_Copy(), retry", $pid, CFGGet($CFGKEY_NOTEPADPATH))
		EndIf
		If $pid = 0 Then Return

		; Wait main window and get handle
		Local $handle = 0
		For $i = 1 To 20
			$handle = GetProcessMainWindow($pid)
			If $handle <> 0 Then ExitLoop
			Sleep(50)
			dbg("HotKey_Copy(), try to get main window's handle", $i)
		Next
		dbg("HotKey_Copy(), main window", $handle)
		If $handle = 0 Then Return

		; Activate editor
		If WinWaitActive($handle, "", 1) <> 0 Then
			; Send CTRL+V
			; http://www.autoitscript.com/wiki/FAQ#Why_does_the_Ctrl_key_get_stuck_down_after_I_run_my_script.3F
			While _IsPressed("10") Or _IsPressed("11") Or _IsPressed("12")
				Sleep(50)
			WEnd
			Send("^v")
		EndIf
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, "HotKey_Copy")
	EndIf
EndFunc

Func HotKey_Appskey()
	Local $index = MgrGetActive()
	If $index >= 0 Then
;~ 		_SendMessage(DataGetHandle($index), $WM_SYSCOMMAND, 0xF100, 0x0) ; SC_KEYMENU
		_SendMessage(DataGetHandle($index), $WM_RBUTTONDOWN, 0x0008, 0x0) ; MK_CONTROL
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, "HotKey_Appskey")
	EndIf
EndFunc

Func HotKey_Func_SetBG($r, $g, $b, $funcSrc)
	Local $index = MgrGetActive()
	If $index >= 0 Then
		dbg("HotKey_Func_SetBG()", $r, $g, $b)

		; Already has config box?
		If WinExists($TITLE_PUTTYCONFIGBOX) Then
			WinActivate($TITLE_PUTTYCONFIGBOX)
			Return
		EndIf

		; Call current PuTTY's reconfig and wait config box
		_PostMessage(DataGetHandle($index), $WM_SYSCOMMAND, 0x0050, 0x0)
		Local $handle = WinWaitActive($TITLE_PUTTYCONFIGBOX, "", 1)

		; Tree
		Local $hTree = GetChildWindow($handle, "SysTreeView32")
		Local $hItem = _GUICtrlTreeView_FindItem($hTree, "Colours")
		_GUICtrlTreeView_SelectItem($hTree, $hItem)

		; ListBox
		Local $hListBox = GetChildWindow($handle, "ListBox")
		_GUICtrlListBox_SetCurSel($hListBox, 2)

		; Fill colors
		ControlSetText("", "", 0x41E, $r)
		ControlSetText("", "", 0x420, $g)
		ControlSetText("", "", 0x422, $b)

		; Apply
		ControlClick("", "", 0x3F1)
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, $funcSrc)
	EndIf
EndFunc

Func HotKey_BG_R()
	HotKey_Func_SetBG(40, 0, 0, "HotKey_BG_R")
EndFunc

Func HotKey_BG_G()
	HotKey_Func_SetBG(0, 40, 0, "HotKey_BG_G")
EndFunc

Func HotKey_BG_B()
	HotKey_Func_SetBG(0, 0, 40, "HotKey_BG_B")
EndFunc

Func HotKey_BG_Clear()
	HotKey_Func_SetBG(0, 0, 0, "HotKey_BG_Clear")
EndFunc

Func HotKey_Func_GUI($show)
	; Sometimes GUI just showed by CTRL+` disappeared very quickly.
	; So block refreshing during showing GUI window
	$g_bRefreshing = True
	If $show Then
;~ 		MgrSwitchToCurrent()                  ; Show last putty window and focus on it
;~ 		MgrSwitchTo_original(MgrGetCurrent()) ; Show last putty window and focus on assist dialog
		MgrGUIShow()
	Else
		WinSetState($g_hGUI, "", @SW_HIDE)
	EndIf
	$g_bRefreshing = False
EndFunc

Func HotKey_GUI_Global()
	Local $showingGUI = BitAND(WinGetState($g_hGUI), 2)
	$g_bManuallyHideGUI = $showingGUI
	HotKey_Func_GUI(Not($g_bManuallyHideGUI))
	If $g_bManuallyHideGUI Then
		TrayItemSetState($g_idTrayHide, $TRAY_CHECKED)
	Else
		TrayItemSetState($g_idTrayHide, $TRAY_UNCHECKED)
	EndIf
EndFunc

Func HotKey_Func_SwitchTo($indexTo, $funcSrc)
	dbg("HotKey_Func_SwitchTo()", $funcSrc, $indexTo)
	Local $index = MgrGetActive()
	If $index >= 0 Or WinActive($g_hGUI) Then
		MgrSwitchTo($indexTo)
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, $funcSrc)
	EndIf
EndFunc

Func HotKey_SwitchToLastOne_Global()
	MgrSwitchToCurrent()
EndFunc

Func HotKey_SwitchTo_Global()
	Local $indexTo = Int(StringRight(@HotKeyPressed, 1)) - 1
	MgrSwitchTo($indexTo)
EndFunc

Func HotKey_SwitchTo()
	Local $indexTo = Int(StringRight(@HotKeyPressed, 1)) - 1
	HotKey_Func_SwitchTo($indexTo, "HotKey_SwitchTo")
EndFunc

Func HotKey_Switch_H()
	Local $indexTo = 0
	HotKey_Func_SwitchTo($indexTo, "HotKey_Switch_H")
EndFunc

Func HotKey_Switch_M()
	Local $indexTo = Int((DataGetLength() - 1) / 2)
	HotKey_Func_SwitchTo($indexTo, "HotKey_Switch_M")
EndFunc

Func HotKey_Switch_L()
	Local $indexTo = DataGetLength() - 1
	HotKey_Func_SwitchTo($indexTo, "HotKey_Switch_L")
EndFunc

Func HotKey_Func_GetNext_Sequential($next)
	Local $n = -1
	Local $index = MgrGetActive()
	If $index >= 0 Then
		$n = Mod($index + $next + DataGetLength(), DataGetLength())
	ElseIf WinActive($g_hGUI) Then
		; No active window, activate selected one in GUI
		$n = MgrGetCurrent()
		If $n < 0 Then $n = 0
	EndIf
	Return $n
EndFunc

Func HotKey_Func_GetNext_Recent($next)
	DumpData($g_avRecentQueue)
	Local $n = -1
	Local $index = MgrGetActive()
	If $index >= 0 Or WinActive($g_hGUI) Then
		Local $handle = 0
		If $next = 1 Then $handle = RQueGetRecent()
		If $next = -1 Then $handle = RQueGetLeastRecent()
		$n = DataGetIndex($handle)
	EndIf
	Return $n
EndFunc

Func HotKey_Func_SwitchToNext($next, $funcNext, $funcSrc)
	Local $index = Execute($funcNext & "($next)")
	dbg("HotKey_Func_SwitchToNext()", $next, $funcNext, $index)
	If $index >= 0 Then
		MgrSwitchTo($index)
	Else
		HotKey_Func_PassAlong(@HotKeyPressed, $funcSrc)
	EndIf
EndFunc

Func HotKey_SwitchToNext()
	HotKey_Func_SwitchToNext(1, "HotKey_Func_GetNext_Sequential", "HotKey_SwitchToNext")
EndFunc

Func HotKey_SwitchToPrev()
	HotKey_Func_SwitchToNext(-1, "HotKey_Func_GetNext_Sequential", "HotKey_SwitchToPrev")
EndFunc

Func HotKey_SwitchToMost()
	HotKey_Func_SwitchToNext(1, "HotKey_Func_GetNext_Recent", "HotKey_SwitchToMost")
EndFunc

Func HotKey_SwitchToLeast()
	HotKey_Func_SwitchToNext(-1, "HotKey_Func_GetNext_Recent", "HotKey_SwitchToLeast")
EndFunc

Func MgrGetActive()
	For $i = 0 To DataGetLength() - 1
		If WinActive(DataGetHandle($i)) Then Return $i
	Next
	return -1
EndFunc

Func MgrGetCurrent()
	return _GUICtrlListView_GetNextItem($g_hListView)
EndFunc

Func MgrGUIShow()
	WinSetState($g_hGUI, "", @SW_SHOW)
	WinActivate($g_hGUI)
	GUICtrlSetState($g_idListView, $GUI_FOCUS)
	; Call $g_oTaskbarList.DeleteTab immediately may not 100% hide the bar,
	; and may take lots of time in "DeleteTab"
	$g_HideTaskbar_AfterRefreshing = _Timer_Init()
EndFunc

Func MgrRefresh()
	If $g_bRefreshing Or $g_bSwitching Then
		dbg("MgrRefresh(), ignored", $g_bRefreshing, $g_bSwitching)
		Return
	EndIf
	$g_bRefreshing = True

	; Refresh data
	Local $bRemoved = False
	Local $showingGUI = BitAND(WinGetState($g_hGUI), 2)
	Local $avNewData = GetAllPuTTYs()
	If DataChanges($avNewData) Then
		dbg("MgrRefresh(), Refresh data!!!")
		If UBound(DataDifference($g_avData, $avNewData)) <> 0 Then
			$bRemoved = True
		EndIf
		If CFGGetInt($CFGKEY_AUTOMAXIMIZE) Then
			Local $diff = DataDifference($avNewData, $g_avData)
			If UBound($diff) <> 0 Then
				_wndMinAnimation(False)
				For $one in $diff
					WinSetState($one, "", @SW_MAXIMIZE)
				Next
				_wndMinAnimation(True)
			EndIf
		EndIf
		DataUpdate($avNewData)
		ListUpdate($g_hListView, $g_avData)
	ElseIf $showingGUI Then
		ListUpdateNames($g_hListView, $g_avData)
	EndIf

	; Refresh GUI, auto show and hide
	Local $index = MgrGetActive()
	If Not($g_bManuallyHideGUI) Then
		If $index >= 0 Then
			If Not($showingGUI) Then
				MgrGUIShow()
			EndIf
		Else
			If Not(WinActive($g_hGUI)) and Not($g_bShowingAbout) Then
				WinSetState($g_hGUI, "", @SW_HIDE)
			EndIf
		EndIf
	EndIf

	; This "$index" (PuTTY widnow) maybe not activated by MgrSwitchTo. So call MgrSwitchTo
	; to perform set list item, maximize, and hide others...
	If $index >= 0 Then MgrSwitchTo_original($index)

	; Did a PuTTY just close? If so activate another one.
	If $bRemoved Then MgrSwitchTo_original(0)

	; Done refreshing
	$g_bRefreshing = False

	; Do switch that not performed which caused by crossing called message loop
	If $g_iSwitch_AfterRefreshing >= 0 Then
		dbg("-MgrRefresh(), Perform last $g_iSwitch_AfterRefreshing", $g_iSwitch_AfterRefreshing)
		MgrSwitchTo($g_iSwitch_AfterRefreshing)
		$g_iSwitch_AfterRefreshing = -1
	EndIf

	; Hide GUI's taskbar
	If $g_HideTaskbar_AfterRefreshing <> 0 Then
		Local $diff = _Timer_Diff($g_HideTaskbar_AfterRefreshing)
		If $diff > 100 Then
			If $diff > 500 Then
				; Try "DeleteTab" multiple times before stopping.
				$g_HideTaskbar_AfterRefreshing = 0
			EndIf
			Local $t = _Timer_Init()
			$g_oTaskbarList.DeleteTab($g_hGUI)
			dbg("HideTaskbar", _Timer_Diff($t), $diff)
		EndIf
	EndIf

	; Write back cfg
	If $g_WriteBackCFG_AfterRefreshing <> 0 Then
		Local $diff = _Timer_Diff($g_WriteBackCFG_AfterRefreshing)
		If $diff > 3 * 1000 Then ; 3 seconds later after CFGSet
			$g_WriteBackCFG_AfterRefreshing = 0
			CFGWriteBack()
		EndIf
	EndIf
EndFunc

Func MgrSwitchToCurrent()
	Local $index = MgrGetCurrent()
	If $index >= 0 Then MgrSwitchTo($index)
EndFunc

Func MgrSwitchTo($index)
	If $g_bSwitching Then Return
	$g_bSwitching = True

	If $g_bRefreshing Then
		; Is in refreshing? Yes, it's called in the middle of "MgrRefresh()"
		; After some debuging, it seems that something happened in ListUpdateNames
		dbg("-MgrSwitchTo($index), Crossed message loop!")
		$g_iSwitch_AfterRefreshing = $index
	Else
		dbg("MgrSwitchTo()", "-->", $index)
		MgrSwitchTo_original($index)
	EndIf

	$g_bSwitching = False
EndFunc

Func MgrSwitchTo_original($index)
	If $index < 0 Or $index >= DataGetLength() Then Return
	MgrActivate($index)
	MgrHideOthers($index)
EndFunc

Func MgrActivate($index)
	_GUICtrlListView_SetItemState($g_hListView, $index, $LVIS_FOCUSED + $LVIS_SELECTED, $LVIS_FOCUSED + $LVIS_SELECTED)
	If $index >= 0 Then
		Local $handle = DataGetHandle($index)
		RQueAddRecent($handle)
		WinSetState($handle, "", @SW_SHOW)
		WinActivate($handle)
	EndIf
EndFunc

Func MgrHideOthers($index)
	If CFGGetInt($CFGKEY_AUTOHIDE) Then
		For $i = 0 To DataGetLength() - 1
			If $i <> $index Then
				$g_oTaskbarList.DeleteTab(DataGetHandle($i))
			EndIf
		Next
	EndIf
EndFunc

Func DataChanges($avNewData)
	If UBound($g_avData) <> UBound($avNewData) Then Return True
	If UBound($g_avData) = 0 Then Return False
	For $one In $avNewData
		If _ArraySearch($g_avData, $one) < 0 Then Return True
	Next
	Return False
EndFunc

Func DataDifference($dataA, $dataB)
	; Return "$dataA - $dataB"
	Local $results[1]
	If UBound($dataA) <> 0 Then
		For $one in $dataA
			If _ArraySearch($dataB, $one) = -1 Then
				_ArrayAdd($results, $one)
			EndIf
		Next
	EndIf
	_ArrayDelete($results, 0)
	return $results
EndFunc

Func DataUpdate($avNewData)
	If UBound($g_avData) = 0 Then
		$g_avData = $avNewData
		$g_avRecentQueue = $avNewData
	ElseIf UBound($avNewData) <> 0 Then
		; Add new items
		For $one In $avNewData
			If $one And _ArraySearch($g_avData, $one) = -1 Then
				_ArrayAdd($g_avData, $one)
			EndIf
			RQueAddNew($one)
		Next
		; Remove old items
		For $i = UBound($g_avData) - 1 To 0 Step -1
			Local $index = _ArraySearch($avNewData, $g_avData[$i])
			If $index = -1 Then
				RQueRemove($g_avData[$i])
				_ArrayDelete($g_avData, $i)
			EndIf
		Next
	Else
		; No new data, remove all avData
		While UBound($g_avData) <> 0
			_ArrayDelete($g_avData, 0)
		WEnd
		RQueRemoveAll()
	EndIf
	DumpData($avNewData)
	DumpData($g_avData)
	DumpData($g_avRecentQueue)
EndFunc

Func DataMove($src, $desc)
	dbg("DataMove() From", $src, "To", $desc)
	DumpData($g_avData)
	Local $data = $g_avData
	Local $item = $data[$src]
	If $src < $desc Then
		For $i = $src To $desc - 1
			$data[$i] = $data[$i + 1]
		Next
	Else
		For $i = $src To $desc + 1 Step -1
			$data[$i] = $data[$i - 1]
		Next
	EndIf
	$data[$desc] = $item
	$g_avData = $data
	DumpData($g_avData)
EndFunc

Func DataGetLength()
	Return UBound($g_avData)
EndFunc

Func DataGetIndex($handle)
	Return _ArraySearch($g_avData, $handle)
EndFunc

Func DataGetHandle($index)
	If $index < 0 Or $index >= DataGetLength() Then Return 0
	Return $g_avData[$index]
EndFunc

Func DataGetTitle($index)
	If $index < 0 Or $index >= DataGetLength() Then Return ""
	return WinGetTitle(DataGetHandle($index))
EndFunc

Func RQueAddNew($item)
	Local $index = _ArraySearch($g_avRecentQueue, $item)
	If $index < 0 Then _ArrayInsert($g_avRecentQueue, 0, $item)
EndFunc

Func RQueAddRecent($item)
	RQueRemove($item)
	If RQueGetLength() = 0 Then
		Local $dummy[1]
		$dummy[0] = $item
		$g_avRecentQueue = $dummy
	Else
		_ArrayAdd($g_avRecentQueue, $item)
	EndIf
EndFunc

Func RQueGetLength()
	return UBound($g_avRecentQueue)
EndFunc

Func RQueGetLeastRecent()
	If RQueGetLength() >= 1 Then Return $g_avRecentQueue[0]
	Return 0
EndFunc

Func RQueGetRecent()
	If RQueGetLength() > 1 Then Return $g_avRecentQueue[RQueGetLength() - 2]
	Return 0
EndFunc

Func RQueRemove($item)
	If RQueGetLength() >= 1 Then
		Local $index = _ArraySearch($g_avRecentQueue, $item)
		If $index >= 0 Then
			_ArrayDelete($g_avRecentQueue, $index)
		EndIf
	EndIf
EndFunc

Func RQueRemoveAll()
	While UBound($g_avRecentQueue) <> 0
		_ArrayDelete($g_avRecentQueue, 0)
	WEnd
EndFunc

Func ListUpdate($hList, $avData)
	Local $lastRowCount = _GUICtrlListView_GetItemCount($g_hListView)
	Local $newRowCount = UBound($avData)
	_GUICtrlListView_DeleteAllItems($hList)
	For $i = 0 To UBound($avData) - 1
		Local $text = $i + 1 & ". " & DataGetTitle($i)
		_GUICtrlListView_AddItem($hList, $text)
	Next
	; Resize GUI
	If $lastRowCount <> $newRowCount Then
		Local $iRowHeight = _GUICtrlListView_GetItemPositionY($g_hListView, 1)
		WinMove($g_hGUI, "", CFGGetInt($CFGKEY_POS_X), CFGGetInt($CFGKEY_POS_Y), CFGGetInt($CFGKEY_WIDTH), _Max($iRowHeight * $newRowCount + 70, $ASSIST_DEFAULT_HEIGHT))
	EndIf
EndFunc

Func ListUpdateNames($hList, $avData)
	For $i = 0 To UBound($avData) - 1
		Local $text = $i + 1 & ". " & DataGetTitle($i)
		Local $textOld = _GUICtrlListView_GetItemText($hList, $i)
		If Not($text = $textOld) then
			_GUICtrlListView_SetItem($hList, $text, $i)
			dbg("New item text:", $text, $textOld, "<<")
		EndIf
	Next
EndFunc

Func dbg($v1="", $v2="", $v3="", $v4="", $v5="")
	If $DEBUG_OUTPUT_BITS = 0 Then Return
	Local $msg = $v1 & " " & $v2 & " " & $v3 & " " & $v4 & " " & $v5 & @CRLF
	If BitAND($DEBUG_OUTPUT_BITS, 1) Then
		ConsoleWrite($msg)
	EndIf
	If BitAND($DEBUG_OUTPUT_BITS, 2) Then
		DllCall("kernel32.dll", "none", "OutputDebugString", "str", $msg)
	EndIf
EndFunc

Func DumpData($data)
	If $DEBUG_OUTPUT_BITS = 0 Then Return
	Local $len = UBound($data)
	dbg("DATA len =", $len, "[" & _ArrayToString($data, ", ", 0, 5) & "]")
EndFunc

Func GetAllPuTTYs()
	Local $results[1]
	Local $var = WinList("[CLASS:PuTTY]")
	For $i = 1 to $var[0][0]
		_ArrayAdd($results, $var[$i][1])
		If Not(CFGGet($CFGKEY_PUTTYPATH)) Then
			CFGSet($CFGKEY_PUTTYPATH, GetModuleFileNameEx(WinGetProcess($var[$i][1])))
		EndIf
	Next
	; Validate below codes to collect more windows
	If 0 Then
		$var = WinList("[CLASS:ConsoleWindowClass]") ; cmd.exe, python.exe and more console windows
		For $i = 1 to $var[0][0]
			_ArrayAdd($results, $var[$i][1])
			If Not(CFGGet($CFGKEY_PUTTYPATH)) Then
				CFGSet($CFGKEY_PUTTYPATH, GetModuleFileNameEx(WinGetProcess($var[$i][1])))
			EndIf
		Next
	EndIf
	_ArrayDelete($results, 0)
	return $results ; Array of handles, all elements are handle
EndFunc

Func GetModuleFileNameEx($_Pid)
	Local $_Hwnd = DllCall("Kernel32.dll", "hwnd", "OpenProcess", "dword", 0x0400 + 0x0010, "int", 0, "dword", $_Pid)
	Local $_Return = DllCall("Psapi.dll", "long", "GetModuleFileNameEx", "hwnd", $_Hwnd[0], "long", 0, "str", 0, "long", 255)
	DllCall("Kernel32.dll", "int", "CloseHandle", "hwnd", $_Hwnd[0])
	If StringInStr($_Return[3], "\") Then Return $_Return[3]
	Return ""
EndFunc

Func GetProcessMainWindow($pid)
	Local $wlist = WinList()
	For $i = 1 To $wlist[0][0]
		Local $handle = $wlist[$i][1]
		If $pid <> WinGetProcess($handle) Then ContinueLoop
		If _WinAPI_GetParent($handle) <> 0 Then ContinueLoop
		If BitAND(_WinAPI_GetWindowLong($handle, $GWL_STYLE), $WS_VISIBLE) = 0 Then ContinueLoop
		Return $handle
	Next
	Return 0
EndFunc

Func GetChildWindow($hWnd, $sClassName)
	If $hWnd = 0 Then Return 0
	Local $hChild = _WinAPI_GetWindow($hWnd, $GW_CHILD)
	While $hChild
		If _WinAPI_GetClassName($hChild) = $sClassName Then Return $hChild
		$hChild = _WinAPI_GetWindow($hChild, $GW_HWNDNEXT)
	WEnd
	Return 0
EndFunc

; see _SendMessage in SendMessage.au3
Func _PostMessage($hWnd, $iMsg, $wParam = 0, $lParam = 0, $iReturn = 0, $wParamType = "wparam", $lParamType = "lparam", $sReturnType = "lresult")
	Local $aResult = DllCall("user32.dll", $sReturnType, "PostMessageW", "hwnd", $hWnd, "uint", $iMsg, $wParamType, $wParam, $lParamType, $lParam)
	If @error Then Return SetError(@error, @extended, "")
	If $iReturn >= 0 And $iReturn <= 4 Then Return $aResult[$iReturn]
	Return $aResult
EndFunc

#region - _wndMinAnimation

; http://www.autoitscript.com/forum/topic/44159-disable-animation-when-maximizeminimize-a-window/

;===============================================================================
;
; Description:  : Toggles wndMinAnimation on or off.
; Parameter(s):  : $value - True or False
; Requirement:  : -
; Return Value(s): : -
; User CallTip:  :
; Author(s):  : Eemuli
; Note(s):   : http://msdn.microsoft.com/en-us/library/windows/desktop/ms724947(v=vs.85).aspx
;
;===============================================================================
Func _wndMinAnimation($value = True)
	Local Const $SPI_SETANIMATION = 0x0049
	Local Const $SPI_GETANIMATION = 0x0048
	Local Const $tagANIMATIONINFO = "uint cbSize;int iMinAnimate"

	Local $struct = DllStructCreate($tagANIMATIONINFO)
	DllStructSetData($struct, "iMinAnimate", $value)
	DllStructSetData($struct, "cbSize", DllStructGetSize($struct))

	Local $aReturn = DllCall('user32.dll', 'int', 'SystemParametersInfo', 'uint', $SPI_SETANIMATION, 'int', DllStructGetSize($struct), _
	   'ptr', DllStructGetPtr($struct), 'uint', 0)
EndFunc   ;==_wndMinAnimation

#endregion - _wndMinAnimation



