#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Version=Beta
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include "..\..\_netcode_Relay.au3"

Local $hRelaySocket = _netcode_SetupTCPRelay('0.0.0.0', 1227, "127.0.0.1", 1225)

_netcode_RelayLoop(True)