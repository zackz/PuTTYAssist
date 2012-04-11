#comments-start

A handy and tiny configuration management tool. Extracted from PuTTYAssist.au3
* Save runtime data in ini, easy to access and save/restore. Automatically
  create ini file and write default items.
* All data cached in memory, only CFGInitData and CFGWriteBack accessed file.
* Delayed write back (using CFGNeedWriteBack)
* Don't too dependent on this, it's still script function, too much keys may
  cause more time

Init:
	Global Const $PATH_INI     = @ScriptDir & "\" & "properties.ini"
	Global Const $SECTION_NAME = "PROPERTIES"
	Global Const $CFGKEY_WIDTH = "WIDTH"
	Func InitCFG()
		CFGInitData($PATH_INI, $SECTION_NAME)
		CFGSetDefault($CFGKEY_WIDTH, 600)
		...
	EndFunc

Access:
	get:
		Local $width = CFGGet($CFGKEY_WIDTH)
	set:
		CFGSet($CFGKEY_WIDTH, 500)
	exist:
		If CFGKeyIndex($CFGKEY_WIDTH) >= 0 Then ...
	default:
		CFGSetDefault($CFGKEY_WIDTH, 600)

Write data back to ini:
	CFGCachedWriteBack()       ; When idle
	CFGCachedWriteBack(False)  ; Or before exit

History:
v3
	In CFGCachedWriteBack, don't actually write data back if nothing changed.
v2
	Add CFGCachedWriteBack() encapsulated CFGNeedWriteBack and CFGWriteBack.
	And save $ini/$section when calling CFGInitData.
v1
	Basic functions extracted from PuTTYAssist

#comments-end

#include-once

Global $cfg_timeLatestSet = 0
Global $cfg_avCFG[1][2] = [[0]]
Global $cfg_ini
Global $cfg_section

Func CFGInitData($ini, $section)
	Local $av = IniReadSection($ini, $section)
	If UBound($av) > 0 Then
		$cfg_avCFG = $av
	EndIf
	$cfg_ini = $ini
	$cfg_section = $section
EndFunc

Func CFGKeyIndex($key)
	For $i = 1 To $cfg_avCFG[0][0]
		; Case insensitive
		If $key = $cfg_avCFG[$i][0] Then Return $i
	Next
	Return -1  ; Not exist
EndFunc

Func CFGGet($key)
	Local $index = CFGKeyIndex($key)
	If $index >= 0 Then
		Return $cfg_avCFG[$index][1]
	Else
		; ... not exist
		Return 0
	EndIf
EndFunc

Func CFGGetInt($key)
	Return Int(CFGGet($key))
EndFunc

Func CFGSetDefault($key, $defaultvalue)
	Local $index = CFGKeyIndex($key)
	If $index < 0 Then
		CFGSet($key, $defaultvalue)
		Return $defaultvalue
	EndIf
	Return $cfg_avCFG[$index][1]
EndFunc

Func CFGSet($key, $value)
	Local $index = CFGKeyIndex($key)
	If $index < 0 Then
		; New key
		$index = $cfg_avCFG[0][0] + 1
		ReDim $cfg_avCFG[$index + 1][2]  ; hope not too many keys...
		$cfg_avCFG[0][0] = $index
		$cfg_avCFG[$index][0] = $key
	ElseIf $value = $cfg_avCFG[$index][1] Then
		; Not changed
		Return
	EndIf
	$cfg_avCFG[$index][1] = $value
	; CFG changed, need write back
	$cfg_timeLatestSet = _Timer_Init()
EndFunc

; Don't call this directly! Always call after checking CFGNeedWriteBack.)
Func CFGWriteBack($ini, $section)
	$cfg_timeLatestSet = 0
	IniWriteSection($ini, $section, $cfg_avCFG)
EndFunc

Func CFGNeedWriteBack($delay)
	If $cfg_timeLatestSet = 0 Then Return False
	; Wait a while for another CFGSet
	Return _Timer_Diff($cfg_timeLatestSet) > $delay
EndFunc

Func CFGCachedWriteBack($cache=True, $delay=3000)
	If $cache Then
		If CFGNeedWriteBack($delay) Then
			CFGWriteBack($cfg_ini, $cfg_section)
		EndIf
	Else
		; Write back immediately
		If $cfg_timeLatestSet <> 0 Then
			CFGWriteBack($cfg_ini, $cfg_section)
		EndIf
	EndIf
EndFunc
