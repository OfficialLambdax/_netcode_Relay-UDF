#include-once
#include "_netcode_Core.au3"

#cs
	Todo

		- UDP (?)

		- Man in the Middle

		- Optional SOCKS5 Authentication for compatibility

		- Reduce CPU usage
			The relay can relay really fast. I think a Gb bandwith isnt a problem for this. However if the relay is
			used just a little or not used at all it will still spam the hell out of Ws2_32.dll.
			Placing a Sleep(10) will just create lag. It wouldnt be a intelligent solution. Something else must be used.
			Something taking the current usage in account or that can react imidiatly when something is coming through.

		- Add Select() for performance

		- Add Black and Whitelists for Incomming Connections


#ce



Global $__net_relay_arTCPSockets[0]
Global $__net_relay_arUDPSockets[0]
Global Const $__net_relay_UDFVersion = "0.1.1"


Func _netcode_SetupTCPRelay($sRelayIP, $sRelayPort, $sRelayToIP, $sRelayToPort)
	__netcode_Init()
	Local $hRelaySocket = _netcode_TCPListen($sRelayPort, $sRelayIP, Default, 200, True)
	if $hRelaySocket = False Then Return SetError(1)

	__netcode_AddTCPRelaySocket($hRelaySocket, $sRelayToIP, $sRelayToPort)

	Return $hRelaySocket
EndFunc

Func _netcode_SetupUDPRelay($sRelayPort, $sRelayToIP, $sRelayToPort)

EndFunc

Func _netcode_RelaySetIPList($hRelaySocket, $vIPList, $bIPListIsWhitelist)

EndFunc

Func _netcode_StopTCPRelay($hRelaySocket)
	If Not __netcode_RemoveTCPRelaySocket($hRelaySocket) Then Return SetError(@error)
	__netcode_TCPCloseSocket($hRelaySocket)
	Return True
EndFunc

Func _netcode_RelayLoop($bLoopForever = False)
	Local $nTCPArSize = UBound($__net_relay_arTCPSockets)
	Local $nUDPArSize = UBound($__net_relay_arUDPSockets)
	Local $nSendBytes = 0

	Do
		$nSendBytes = 0
		For $i = 0 To $nTCPArSize - 1
			$nSendBytes += __netcode_RelayTCPLoop($__net_relay_arTCPSockets[$i])

			; ~ todo relay UDP
		Next

;~ 		if $nSendBytes = 0 Then Sleep(10)
	Until Not $bLoopForever
EndFunc

Func __netcode_AddTCPRelaySocket($hRelaySocket, $sRelayToIP, $sRelayToPort)
	_storageS_Overwrite($hRelaySocket, '_netcode_relay_RelayToIP', $sRelayToIP)
	_storageS_Overwrite($hRelaySocket, '_netcode_relay_RelayToPort', $sRelayToPort)

	Local $arClients[0][2]
	_storageS_Overwrite($hRelaySocket, '_netcode_relay_Clients', $arClients)

	Local $nArSize = UBound($__net_relay_arTCPSockets)

	ReDim $__net_relay_arTCPSockets[$nArSize + 1]
	$__net_relay_arTCPSockets[$nArSize] = $hRelaySocket
EndFunc

Func __netcode_RemoveTCPRelaySocket($hRelaySocket)
	Local $nArSize = UBound($__net_relay_arTCPSockets)

	Local $nIndex = -1
	For $i = 0 To $nArSize - 1
		if $__net_relay_arTCPSockets[$i] = $hRelaySocket Then
			$nIndex = $i
			ExitLoop
		EndIf
	Next
	if $nIndex = -1 Then Return SetError(1) ; this isnt a relay socket

	_storageS_TidyGroupVars($hRelaySocket)

	$__net_relay_arTCPSockets[$nIndex] = $__net_relay_arTCPSockets[$nArSize - 1]
	ReDim $__net_relay_arTCPSockets[$nArSize - 1]

	Return True
EndFunc

Func __netcode_CheckRelayIPList($hRelaySocket, $hSocket)
	; ~ todo
	Return True
EndFunc

Func __netcode_AddTCPRelayClient($hRelaySocket, $arClients, $hSocket, $hSocketTo)
	Local $nArSize = UBound($arClients)

	ReDim $arClients[$nArSize + 1][2]
	$arClients[$nArSize][0] = $hSocket
	$arClients[$nArSize][1] = $hSocketTo

	_storageS_Overwrite($hRelaySocket, '_netcode_relay_Clients', $arClients)

	; add temp storage vars
	_storageS_Overwrite($hSocket, '_netcode_relay_buffer', '')
	_storageS_Overwrite($hSocketTo, '_netcode_relay_buffer', '')
EndFunc

Func __netcode_RemoveTCPRelayClient($hRelaySocket, $arClients, $nIndex)
	Local $nArSize = UBound($arClients)

	__netcode_TCPCloseSocket($arClients[$nIndex][0])
	__netcode_TCPCloseSocket($arClients[$nIndex][1])

	; tidy temp storage vars
	_storageS_TidyGroupVars($arClients[$nIndex][0])
	_storageS_TidyGroupVars($arClients[$nIndex][1])

	$arClients[$nIndex][0] = $arClients[$nArSize - 1][0]
	$arClients[$nIndex][1] = $arClients[$nArSize - 1][1]
	ReDim $arClients[$nArSize - 1][2]

	_storageS_Overwrite($hRelaySocket, '_netcode_relay_Clients', $arClients)
EndFunc

Func __netcode_RelayTCPLoop($hRelaySocket)

	Local $arClients = _storageS_Read($hRelaySocket, '_netcode_relay_Clients')

	Local $hSocket = __netcode_TCPAccept($hRelaySocket)
	if $hSocket <> -1 Then
		__netcode_RelayDebug($hRelaySocket, 1, $hSocket)

		if __netcode_CheckRelayIPList($hRelaySocket, $hSocket) Then
			Local $sRelayToIP = _storageS_Read($hRelaySocket, '_netcode_relay_RelayToIP')
			Local $sRelayToPort = _storageS_Read($hRelaySocket, '_netcode_relay_RelayToPort')

			Local $hSocketTo = __netcode_TCPConnect($sRelayToIP, $sRelayToPort)
			if $hSocketTo <> -1 Then
				__netcode_AddTCPRelayClient($hRelaySocket, $arClients, $hSocket, $hSocketTo)
				__netcode_RelayDebug($hRelaySocket, 3, $hSocket, $hSocketTo)

			Else
				__netcode_TCPCloseSocket($hSocket)
				__netcode_RelayDebug($hRelaySocket, 2, $hSocket)

			EndIf

		Else
			__netcode_TCPCloseSocket($hSocket)
			__netcode_RelayDebug($hRelaySocket, 6, $hSocket)

		EndIf
	EndIf

	Local $nArSize = UBound($arClients)
	Local $nSendBytes = 0

	For $i = 0 To $nArSize - 1
		; read from incomming and send to outgoing
		If Not __netcode_RelayRecvAndSend($arClients[$i][0], $arClients[$i][1]) Then
			__netcode_RemoveTCPRelayClient($hRelaySocket, $arClients, $i)
			__netcode_RelayDebug($hRelaySocket, 4, $arClients[$i][0], $arClients[$i][1])
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes
			if $nBytes > 0 Then __netcode_RelayDebug($hRelaySocket, 5, $arClients[$i][0], $arClients[$i][1], $nBytes)

		EndIf

		; read from outgoing and send to incomming
		if Not __netcode_RelayRecvAndSend($arClients[$i][1], $arClients[$i][0]) Then
			__netcode_RemoveTCPRelayClient($hRelaySocket, $arClients, $i)
			__netcode_RelayDebug($hRelaySocket, 4, $arClients[$i][1], $arClients[$i][0])
			ContinueLoop

		Else
			$nBytes = @extended
			$nSendBytes += $nBytes
			if $nBytes > 0 Then __netcode_RelayDebug($hRelaySocket, 5, $arClients[$i][1], $arClients[$i][0], $nBytes)

		EndIf
	Next

	Return $nSendBytes

EndFunc

#cs
Func __netcode_RelayRecvAndSend_Backup($hSocket, $hSocketTo)
;~ 	Local $sPackages = __netcode_RelayRecvPackages($hSocket)
	Local $sPackages = __netcode_RecvPackages($hSocket)
	if @error Then Return False
	if $sPackages = '' Then Return True

	Local $nBytes = __netcode_TCPSend($hSocketTo, StringToBinary($sPackages))
	$nError = @error
;~ 	if $nError Then MsgBox(0, "", $nError)
	if $nError Then Return False

	Return SetError(0, $nBytes, True)
EndFunc
#ce

Func __netcode_RelayRecvAndSend($hSocket, $hSocketTo)
;~ 	Local $sPackages = __netcode_RelayRecvPackages($hSocket)

	Local $sPackages = _storageS_Read($hSocket, '_netcode_relay_buffer')
	if $sPackages = "" Then
		$sPackages = __netcode_RecvPackages($hSocket)
		if @error Then Return False
		if $sPackages = '' Then Return True

		_storageS_Overwrite($hSocket, '_netcode_relay_buffer', $sPackages)
	EndIf

	Local $nBytes = __netcode_TCPSend($hSocketTo, StringToBinary($sPackages), False)
	Local $nError = @error
	if $nError <> 10035 Then
		_storageS_Overwrite($hSocket, '_netcode_relay_buffer', '')
		$nError = 0
	EndIf
;~ 	if $nError Then MsgBox(0, "", $nError)
	if $nError Then Return False

	Return SetError(0, $nBytes, True)
EndFunc

Func __netcode_RelayRecvPackages(Const $hSocket)
	Local $sPackages = ''
	Local $sTCPRecv = ''
	Local $hTimer = TimerInit()

	Do

		$sTCPRecv = __netcode_TCPRecv($hSocket)
		if @extended = 1 Then
			if $sPackages <> '' Then ExitLoop ; in case the client send something and then closed his socket instantly.
			Return SetError(1, 0, False)
		EndIf

		$sPackages &= BinaryToString($sTCPRecv)
		; todo ~ check size and if it exceeds the max Recv Buffer Size
		; if then just Exitloop instead of discarding it

		if TimerDiff($hTimer) > 20 Then ExitLoop

	Until $sTCPRecv = ''

	Return $sPackages
EndFunc

#cs
	$nInformation
	1 = new connection
	2 = Couldnt connect
	3 = bind to
	4 = disconnected
	5 = send bytes
	6 = incoming is blocked

#ce
Func __netcode_RelayDebug($hRelaySocket, $nInformation, $Element0, $Element1 = "", $Element2 = "")

	Switch $nInformation
		Case 1
			__netcode_Debug("Relay @ " & $hRelaySocket & " New Incomming Connection @ " & $Element0)

		Case 2
			__netcode_Debug("Relay @ " & $hRelaySocket & " Couldnt connect to Relay Destination. Disconnected incomming @ " & $Element0)

		Case 3
			__netcode_Debug("Relay @ " & $hRelaySocket & " Bind @ " & $Element0 & " To @ " & $Element1)

		Case 4
			__netcode_Debug("Relay @ " & $hRelaySocket & " Disconnected @ " & $Element0 & " & @ " & $Element1)

		Case 5
			__netcode_Debug("Relay @ " & $hRelaySocket & " Send Data from @ " & $Element0 & " To @ " & $Element1 & " = " & Round($Element2 / 1024, 2) & " KB")

		Case 6
			__netcode_Debug("Relay @ " & $hRelaySocket & " Incomming Connection was blocked @ " & $Element0)

	EndSwitch


EndFunc