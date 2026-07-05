use framework "AppKit"
use framework "Foundation"
on run {input, parameters}

	-- Normalizar input (Automator puede pasar missing value, ruta en texto o un solo item)
	set input to my normalizeInput(input)
	set input to my filterExistingFiles(input)
	if input is {} then
		set lastImgDir to my getPref("lastImgDir", "")
		if lastImgDir is not "" and my pathExists(lastImgDir) then
			set input to my chooseImageFiles("Selecciona las imagenes a procesar:", lastImgDir)
		else
			set input to my chooseImageFiles("Selecciona las imagenes a procesar:", missing value)
		end if
	end if

	-- Elegir logo (PNG)
	set lastLogoDir to my getPref("lastLogoDir", "")
	if lastLogoDir is not "" and my pathExists(lastLogoDir) then
		set wmPath to my chooseSingleFile("Elige tu logo (PNG con fondo transparente):", lastLogoDir, {"png"})
	else
		set wmPath to my chooseSingleFile("Elige tu logo (PNG con fondo transparente):", missing value, {"png"})
	end if

	-- Ruta ImageMagick
	set magickPath to "/opt/homebrew/bin/magick"
	if my isExecutableFile(magickPath) is false then
		set magickPath to "/usr/local/bin/magick"
		if my isExecutableFile(magickPath) is false then
			my showMessage("No encontre ImageMagick (magick).", "Instalalo con:\nbrew install imagemagick")
			return input
		end if
	end if

-- Cargar defaults guardados
    set dPct to (my getPref("wmPct", "18")) as integer
    set dOp to (my getPref("wmOpacity", "35")) as integer
    set dMargin to (my getPref("wmMargin", "30")) as integer
    set dQ to (my getPref("jpgQuality", "98")) as integer

	-- Previsualizacion para validar parametros
	set lastPos to my getPref("position", "Arriba derecha")
	set approvedPreview to false
	repeat until approvedPreview is true
		-- Formulario unico
		set p to my promptParams(dPct, dOp, dMargin, dQ, lastPos)
		set wmPct to wmPct of p
		set wmOpacity to wmOpacity of p
		set wmMargin to wmMargin of p
		set jpgQuality to jpgQuality of p
		set posChoice to posChoice of p
		set dPct to wmPct
		set dOp to wmOpacity
		set dMargin to wmMargin
		set dQ to jpgQuality
		set lastPos to posChoice

		set gravity to "northeast"
		if posChoice is "Arriba izquierda" then set gravity to "northwest"
		if posChoice is "Arriba derecha" then set gravity to "northeast"
		if posChoice is "Abajo izquierda" then set gravity to "southwest"
		if posChoice is "Abajo derecha" then set gravity to "southeast"
		if posChoice is "Centro" then set gravity to "center"

		-- Generar previsualizacion de la primera imagen
		set previewSrc to my toPosixPath(item 1 of input)
		set wStr to my runShell(my shellQuote(magickPath) & " identify -format %w " & my shellQuote(previewSrc))
		set wInt to wStr as integer
		set wmW to (wInt * wmPct) div 100
		if wmW < 1 then set wmW to 1
		set previewPath to "/tmp/watermark_preview.jpg"
		set previewCmd to quoted form of magickPath & " " & quoted form of previewSrc & " -auto-orient " & ¬
			"\\( " & quoted form of wmPath & " -alpha on -resize " & wmW & "x \\) " & ¬
			"-gravity " & gravity & " -geometry +" & wmMargin & "+" & wmMargin & " " & ¬
			"-compose dissolve -define compose:args=" & wmOpacity & " -composite " & ¬
			"-sampling-factor 4:4:4 -quality " & jpgQuality & " " & ¬
			quoted form of previewPath
		try
			my runShell("/bin/zsh -lc " & my shellQuote(previewCmd))
			set previewPid to my openQuickLook(previewPath)
		on error errMsg
			my showMessage("Error generando previsualizacion.", errMsg)
			return input
		end try

		set chosenButton to my askChoice("Previsualizacion generada.", "Verifica la primera imagen y confirma si los parametros son correctos.", {"Modificar", "Aceptar"}, "Aceptar")
		if chosenButton is "Aceptar" then
			my closeQuickLook(previewPid)
			set approvedPreview to true
		else
			my closeQuickLook(previewPid)
		end if
	end repeat

	-- Carpeta destino
	set lastOutDir to my getPref("lastOutDir", "")
	if lastOutDir is not "" and my pathExists(lastOutDir) then
		set outDir to my chooseOutputFolder("Selecciona la carpeta destino:", lastOutDir)
	else
		set outDir to my chooseOutputFolder("Selecciona la carpeta destino:", missing value)
	end if
	if outDir does not end with "/" then set outDir to outDir & "/"

	-- Log (solo si hay errores)
	set logPath to my desktopPath() & "watermark_app_log.txt"
	set logCreated to false
	set errorCount to 0

	set startTime to my nowSeconds()
	set totalCount to count of input
	set outputPaths to {}

	-- Barra de progreso
	set progress to my startProgressWindow("Procesando imagenes...", totalCount)

	repeat with f in input
		my advanceProgressWindow(progress)
		set inPath to my toPosixPath(f)
		set baseName to my filenameNoExt(inPath)
		set outPath to outDir & baseName & "_wm.jpg"
		set end of outputPaths to outPath

		-- Obtener ancho de la foto
		set wStr to my runShell(my shellQuote(magickPath) & " identify -format %w " & my shellQuote(inPath))
		set wInt to wStr as integer
		set wmW to (wInt * wmPct) div 100
		if wmW < 1 then set wmW to 1

		-- Comando (una sola linea)
		set cmd to quoted form of magickPath & " " & quoted form of inPath & " -auto-orient " & ¬
			"\\( " & quoted form of wmPath & " -alpha on -resize " & wmW & "x \\) " & ¬
			"-gravity " & gravity & " -geometry +" & wmMargin & "+" & wmMargin & " " & ¬
			"-compose dissolve -define compose:args=" & wmOpacity & " -composite " & ¬
			"-sampling-factor 4:4:4 -quality " & jpgQuality & " " & ¬
			quoted form of outPath

		try
			my runShell("/bin/zsh -lc " & my shellQuote(cmd))
		on error errMsg
			if logCreated is false then
				my appendTextLine(logPath, "---- RUN " & my nowDateText() & " ----")
				set logCreated to true
			end if
			set errorCount to errorCount + 1
			my appendTextLine(logPath, "ERROR: " & inPath & " :: " & errMsg)
			my showMessage("Error procesando:\n" & inPath, errMsg)
		end try
	end repeat

	my endProgressWindow(progress)
	set elapsedSec to (my nowSeconds() - startTime) as real
	set elapsedText to my formatETA(elapsedSec)

	-- Abrir resultados en Vista Previa
	if outputPaths is not {} then
		try
			my runShell("/usr/bin/open -a Preview " & my joinQuotedPaths(outputPaths))
		end try
	end if

	-- Guardar ultimos valores para la proxima ejecucion
	if input is not {} then
		my setPref("lastImgDir", my parentDirPath(my toPosixPath(item 1 of input)))
	end if
	my setPref("lastLogoDir", my parentDirPath(wmPath))
	my setPref("lastOutDir", outDir)
	my setPref("wmPct", wmPct as text)
	my setPref("wmOpacity", wmOpacity as text)
	my setPref("wmMargin", wmMargin as text)
	my setPref("jpgQuality", jpgQuality as text)
	my setPref("position", posChoice as text)

	set logInfo to "Sin errores."
	if errorCount > 0 then
		set logInfo to "Errores: " & errorCount & "\nLog:\n" & logPath
	end if
	my showProgressSummary(progress, outDir, totalCount, elapsedText, logInfo)
	return input
end run


-- Helpers
on askNumber(promptText, defaultValue)
	set t to my promptForText(promptText, defaultValue as text)
	try
		set n to t as integer
	on error
		set n to defaultValue as integer
	end try
	return n
end askNumber

on filenameNoExt(p)
	set nsPath to current application's NSString's stringWithString:p
	return ((nsPath's lastPathComponent()'s stringByDeletingPathExtension()) as text)
end filenameNoExt

on parentDirPath(p)
	set nsPath to current application's NSString's stringWithString:p
	set dirPath to ((nsPath's stringByDeletingLastPathComponent()) as text)
	if dirPath does not end with "/" then set dirPath to dirPath & "/"
	return dirPath
end parentDirPath

on openQuickLook(filePath)
	try
		set pidStr to my runShell("/bin/sh -c " & my shellQuote("/usr/bin/qlmanage -p " & my shellQuote(filePath) & " >/dev/null 2>&1 & echo $!"))
		return pidStr as integer
	on error
		return 0
	end try
end openQuickLook

on closeQuickLook(pidVal)
	try
		if pidVal is not 0 then
			my runShell("/bin/kill " & pidVal)
		end if
	end try
end closeQuickLook

on joinQuotedPaths(pathsList)
	set parts to ""
	repeat with p in pathsList
		set parts to parts & " " & quoted form of (p as text)
	end repeat
	return parts
end joinQuotedPaths

on pathExists(p)
	return my isDirectoryPath(p)
end pathExists

-- Preferencias persistentes (defaults)
on getPref(key, defaultValue)
	try
		set defaults to current application's NSUserDefaults's alloc()'s initWithSuiteName:"com.watermark.app"
		set valueText to defaults's stringForKey:key
		if valueText is missing value then return defaultValue
		return valueText as text
	on error
		return defaultValue
	end try
end getPref

on setPref(key, value)
	set defaults to current application's NSUserDefaults's alloc()'s initWithSuiteName:"com.watermark.app"
	(defaults's setObject:value forKey:key)
	defaults's synchronize()
end setPref

on promptParams(defaultPct, defaultOpacity, defaultMargin, defaultQuality, defaultPos)
	set formValues to my promptParamsForm(defaultPct, defaultOpacity, defaultMargin, defaultQuality, defaultPos)
	set pctVal to my toInt(wmPct of formValues, defaultPct)
	set opVal to my toInt(wmOpacity of formValues, defaultOpacity)
	set marginVal to my toInt(wmMargin of formValues, defaultMargin)
	set qualityVal to my toInt(jpgQuality of formValues, defaultQuality)
	set posStr to posChoice of formValues

	if pctVal < 1 then set pctVal to 1
	if opVal < 0 then set opVal to 0
	if opVal > 100 then set opVal to 100
	if marginVal < 0 then set marginVal to 0
	if qualityVal < 80 then set qualityVal to 80
	if qualityVal > 100 then set qualityVal to 100

	return {wmPct:pctVal, wmOpacity:opVal, wmMargin:marginVal, jpgQuality:qualityVal, posChoice:posStr}
end promptParams

on promptParamsForm(defaultPct, defaultOpacity, defaultMargin, defaultQuality, defaultPos)
	set scriptLines to {"use framework \"Foundation\"", "use framework \"AppKit\"", "set appInstance to current application's NSApplication's sharedApplication()", "appInstance's setActivationPolicy:(current application's NSApplicationActivationPolicyRegular)", "appInstance's activateIgnoringOtherApps:true", "set alert to current application's NSAlert's alloc()'s init()", "alert's setMessageText:\"Parametros de marca de agua\"", "alert's setInformativeText:\"Configura los valores y presiona Continuar.\"", "(alert's addButtonWithTitle:\"Continuar\")", "(alert's addButtonWithTitle:\"Cancelar\")", "set boxW to 360", "set boxH to 185", "set containerView to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {boxW, boxH}}"}
	set scriptLines to scriptLines & {"set lbl1 to current application's NSTextField's alloc()'s initWithFrame:{{0, 150}, {130, 24}}", "lbl1's setStringValue:\"Tamano (%)\"", "lbl1's setBezeled:false", "lbl1's setDrawsBackground:false", "lbl1's setEditable:false", "lbl1's setSelectable:false", "set fld1 to current application's NSTextField's alloc()'s initWithFrame:{{140, 145}, {200, 24}}", "fld1's setStringValue:" & my appleScriptString(defaultPct as text), "fld1's setEditable:true", "fld1's setSelectable:true", "fld1's setBezeled:true", "fld1's setDrawsBackground:true"}
	set scriptLines to scriptLines & {"set lbl2 to current application's NSTextField's alloc()'s initWithFrame:{{0, 115}, {130, 24}}", "lbl2's setStringValue:\"Opacidad (0-100)\"", "lbl2's setBezeled:false", "lbl2's setDrawsBackground:false", "lbl2's setEditable:false", "lbl2's setSelectable:false", "set fld2 to current application's NSTextField's alloc()'s initWithFrame:{{140, 110}, {200, 24}}", "fld2's setStringValue:" & my appleScriptString(defaultOpacity as text), "fld2's setEditable:true", "fld2's setSelectable:true", "fld2's setBezeled:true", "fld2's setDrawsBackground:true"}
	set scriptLines to scriptLines & {"set lbl3 to current application's NSTextField's alloc()'s initWithFrame:{{0, 80}, {130, 24}}", "lbl3's setStringValue:\"Margen (px)\"", "lbl3's setBezeled:false", "lbl3's setDrawsBackground:false", "lbl3's setEditable:false", "lbl3's setSelectable:false", "set fld3 to current application's NSTextField's alloc()'s initWithFrame:{{140, 75}, {200, 24}}", "fld3's setStringValue:" & my appleScriptString(defaultMargin as text), "fld3's setEditable:true", "fld3's setSelectable:true", "fld3's setBezeled:true", "fld3's setDrawsBackground:true"}
	set scriptLines to scriptLines & {"set lbl4 to current application's NSTextField's alloc()'s initWithFrame:{{0, 45}, {130, 24}}", "lbl4's setStringValue:\"Calidad JPG (80-100)\"", "lbl4's setBezeled:false", "lbl4's setDrawsBackground:false", "lbl4's setEditable:false", "lbl4's setSelectable:false", "set fld4 to current application's NSTextField's alloc()'s initWithFrame:{{140, 40}, {200, 24}}", "fld4's setStringValue:" & my appleScriptString(defaultQuality as text), "fld4's setEditable:true", "fld4's setSelectable:true", "fld4's setBezeled:true", "fld4's setDrawsBackground:true"}
	set scriptLines to scriptLines & {"set lbl5 to current application's NSTextField's alloc()'s initWithFrame:{{0, 10}, {130, 24}}", "lbl5's setStringValue:\"Posicion\"", "lbl5's setBezeled:false", "lbl5's setDrawsBackground:false", "lbl5's setEditable:false", "lbl5's setSelectable:false", "set popPos to current application's NSPopUpButton's alloc()'s initWithFrame:{{140, 5}, {200, 24}} pullsDown:false", "popPos's setEnabled:true", "repeat with itemTitle in {\"Arriba izquierda\", \"Arriba derecha\", \"Abajo izquierda\", \"Abajo derecha\", \"Centro\"}", "(popPos's addItemWithTitle:(itemTitle as text))", "end repeat", "(popPos's selectItemWithTitle:" & my appleScriptString(defaultPos as text) & ")"}
	set scriptLines to scriptLines & {"containerView's addSubview:lbl1", "containerView's addSubview:fld1", "containerView's addSubview:lbl2", "containerView's addSubview:fld2", "containerView's addSubview:lbl3", "containerView's addSubview:fld3", "containerView's addSubview:lbl4", "containerView's addSubview:fld4", "containerView's addSubview:lbl5", "containerView's addSubview:popPos", "alert's setAccessoryView:containerView", "appInstance's activateIgnoringOtherApps:true", "set responseCode to (alert's runModal()) as integer", "if responseCode is not 1000 then error number -128", "set outLines to {\"wmPct=\" & ((fld1's stringValue()) as text), \"wmOpacity=\" & ((fld2's stringValue()) as text), \"wmMargin=\" & ((fld3's stringValue()) as text), \"jpgQuality=\" & ((fld4's stringValue()) as text), \"posChoice=\" & ((popPos's titleOfSelectedItem()) as text)}", "set oldTids to AppleScript's text item delimiters", "set AppleScript's text item delimiters to linefeed", "set outText to outLines as text", "set AppleScript's text item delimiters to oldTids", "return outText"}
	try
		set rawText to my runOSA(scriptLines)
	on error errMsg number errNum
		if my isUserCancelError(errMsg, errNum) then error number -128
		error errMsg number errNum
	end try
	return my parsePromptParamsResult(rawText)
end promptParamsForm

on parsePromptParamsResult(rawText)
	set lineItems to my splitLines(rawText)
	return {wmPct:my valueForSerializedKey(lineItems, "wmPct"), wmOpacity:my valueForSerializedKey(lineItems, "wmOpacity"), wmMargin:my valueForSerializedKey(lineItems, "wmMargin"), jpgQuality:my valueForSerializedKey(lineItems, "jpgQuality"), posChoice:my valueForSerializedKey(lineItems, "posChoice")}
end parsePromptParamsResult

on valueForSerializedKey(lineItems, keyName)
	set keyPrefix to keyName & "="
	repeat with lineText in lineItems
		set currentLine to contents of lineText
		if currentLine starts with keyPrefix then
			return text ((length of keyPrefix) + 1) thru -1 of currentLine
		end if
	end repeat
	error "Missing serialized key: " & keyName number 1001
end valueForSerializedKey

on normalizeInput(rawInput)
	if rawInput is missing value then return {}
	try
		if (class of rawInput is list) then return rawInput
	on error
		-- fall through
	end try
	return {rawInput}
end normalizeInput

on toPosixPath(f)
	try
		return POSIX path of (f as alias)
	on error
		try
			return POSIX path of (POSIX file f)
		on error
			return POSIX path of f
		end try
	end try
end toPosixPath

on filterExistingFiles(rawList)
	set outList to {}
	repeat with f in rawList
		try
			set p to my toPosixPath(f)
			if my isRegularFile(p) then
			set end of outList to p
			end if
		on error
			-- skip invalid items
		end try
	end repeat
	return outList
end filterExistingFiles

on chooseImageFiles(promptText, defaultDir)
	set scriptLines to {"set chosenItems to choose file with prompt " & my appleScriptString(promptText) & " of type {\"public.image\"} with multiple selections allowed"}
	if defaultDir is not missing value and defaultDir is not "" and my pathExists(defaultDir) then
		set scriptLines to {"set chosenItems to choose file with prompt " & my appleScriptString(promptText) & " of type {\"public.image\"} default location ((POSIX file " & my appleScriptString(defaultDir) & ") as alias) with multiple selections allowed"}
	end if
	set scriptLines to scriptLines & {"set outText to \"\"", "repeat with f in chosenItems", "set outText to outText & POSIX path of f & linefeed", "end repeat", "return outText"}
	return my runChoicePaths(scriptLines)
end chooseImageFiles

on chooseSingleFile(promptText, defaultDir, allowedTypes)
	set typeLiteral to my appleScriptListLiteral(allowedTypes)
	if defaultDir is not missing value and defaultDir is not "" and my pathExists(defaultDir) then
		return my runOSA({"return POSIX path of (choose file with prompt " & my appleScriptString(promptText) & " of type " & typeLiteral & " default location ((POSIX file " & my appleScriptString(defaultDir) & ") as alias))"})
	end if
	return my runOSA({"return POSIX path of (choose file with prompt " & my appleScriptString(promptText) & " of type " & typeLiteral & ")"})
end chooseSingleFile

on chooseOutputFolder(promptText, defaultDir)
	if defaultDir is not missing value and defaultDir is not "" and my pathExists(defaultDir) then
		set folderPath to my runOSA({"return POSIX path of (choose folder with prompt " & my appleScriptString(promptText) & " default location ((POSIX file " & my appleScriptString(defaultDir) & ") as alias))"})
	else
		set folderPath to my runOSA({"return POSIX path of (choose folder with prompt " & my appleScriptString(promptText) & ")"})
	end if
	if folderPath does not end with "/" then set folderPath to folderPath & "/"
	return folderPath
end chooseOutputFolder

on chooseFilesWithPanel(promptText, defaultDir, allowedTypes, allowMultiple, chooseDirectories)
	if my asBoolean(chooseDirectories) then
		return {my chooseOutputFolder(promptText, defaultDir)}
	end if
	if my asBoolean(allowMultiple) then
		set chosenItems to my chooseImageFiles(promptText, defaultDir)
		set chosenPaths to {}
		repeat with f in chosenItems
			set end of chosenPaths to POSIX path of f
		end repeat
		return chosenPaths
	end if
	return {my chooseSingleFile(promptText, defaultDir, allowedTypes)}
end chooseFilesWithPanel

on asBoolean(valueObj)
	if class of valueObj is boolean then return valueObj
	if class of valueObj is list then
		if (count of valueObj) is 0 then return false
		return my asBoolean(item 1 of valueObj)
	end if
	if valueObj is missing value then return false
	try
		return (valueObj as boolean)
	on error
		return false
	end try
end asBoolean

on promptForText(promptText, defaultValue)
	try
		return my runOSA({"set d to display dialog " & my appleScriptString(promptText) & " default answer " & my appleScriptString(defaultValue as text) & " buttons {\"Cancelar\", \"OK\"} default button \"OK\" cancel button \"Cancelar\"", "return text returned of d"})
	on error errMsg number errNum
		if errNum is 1 or errNum is -128 then error number -128
		error errMsg number errNum
	end try
end promptForText

on askChoice(titleText, informativeText, buttonList, defaultButton)
	try
		return my runOSA({"set d to display dialog " & my appleScriptString(titleText & return & return & informativeText) & " buttons " & my appleScriptListLiteral(buttonList) & " default button " & my appleScriptString(defaultButton), "return button returned of d"})
	on error errMsg number errNum
		if my isUserCancelError(errMsg, errNum) then error number -128
		error errMsg number errNum
	end try
end askChoice

on showMessage(titleText, informativeText)
	my runOSA({"display dialog " & my appleScriptString(titleText & return & return & informativeText) & " buttons {\"OK\"} default button \"OK\""})
end showMessage

on runShell(commandText)
	set task to current application's NSTask's alloc()'s init()
	set outPipe to current application's NSPipe's pipe()
	task's setLaunchPath:"/bin/zsh"
	task's setArguments:{"-lc", commandText & " 2>&1"}
	task's setStandardOutput:outPipe
	task's |launch|()
	task's |waitUntilExit|()

	set outputData to (outPipe's fileHandleForReading()'s readDataToEndOfFile())
	set outputText to my stringFromData(outputData)
	set exitCode to (task's terminationStatus()) as integer
	if exitCode is not 0 then error outputText number exitCode
	return my trimText(outputText)
end runShell

on runOSA(scriptLines)
	set cmd to "/usr/bin/osascript"
	repeat with lineText in scriptLines
		set cmd to cmd & " -e " & my shellQuote(lineText as text)
	end repeat
	return my runShell(cmd)
end runOSA

on runChoicePaths(scriptLines)
	try
		set outputText to my runOSA(scriptLines)
	on error errMsg number errNum
		if my isUserCancelError(errMsg, errNum) then error number -128
		error errMsg number errNum
	end try
	return my splitLines(outputText)
end runChoicePaths

on chooseFromListValue(itemList, promptText, defaultValue)
	try
		set outputText to my runOSA({"set pickedItems to choose from list " & my appleScriptListLiteral(itemList) & " with prompt " & my appleScriptString(promptText) & " default items {" & my appleScriptString(defaultValue) & "}", "if pickedItems is false then error number -128", "return item 1 of pickedItems"})
		return outputText
	on error errMsg number errNum
		if my isUserCancelError(errMsg, errNum) then return false
		error errMsg number errNum
	end try
end chooseFromListValue

on isUserCancelError(errMsg, errNum)
	if errNum is -128 then return true
	if errNum is 1 then
		set errText to errMsg as text
		if errText contains "(-128)" then return true
	end if
	return false
end isUserCancelError

on splitLines(rawText)
	set cleanText to my trimText(rawText)
	if cleanText is "" then return {}
	set oldTids to AppleScript's text item delimiters
	set AppleScript's text item delimiters to linefeed
	set parts to text items of cleanText
	set AppleScript's text item delimiters to oldTids
	return parts
end splitLines

on appleScriptString(t)
	set s to t as text
	set nsText to current application's NSString's stringWithString:s
	set escapedText to nsText's stringByReplacingOccurrencesOfString:"\\" withString:"\\\\"
	set escapedText to escapedText's stringByReplacingOccurrencesOfString:"\"" withString:"\\\""
	set escapedText to escapedText's stringByReplacingOccurrencesOfString:(character id 13) withString:""
	return "\"" & (escapedText as text) & "\""
end appleScriptString

on appleScriptListLiteral(itemList)
	set literalItems to {}
	repeat with itemValue in itemList
		set end of literalItems to my appleScriptString(itemValue as text)
	end repeat
	set oldTids to AppleScript's text item delimiters
	set AppleScript's text item delimiters to ", "
	set literalText to "{" & (literalItems as text) & "}"
	set AppleScript's text item delimiters to oldTids
	return literalText
end appleScriptListLiteral

on stringFromData(dataValue)
	if dataValue is missing value then return ""
	set nsString to current application's NSString's alloc()'s initWithData:dataValue encoding:(current application's NSUTF8StringEncoding)
	if nsString is missing value then return ""
	return nsString as text
end stringFromData

on trimText(t)
	set nsText to current application's NSString's stringWithString:(t as text)
	set trimmed to nsText's stringByTrimmingCharactersInSet:(current application's NSCharacterSet's whitespaceAndNewlineCharacterSet())
	return trimmed as text
end trimText

on shellQuote(t)
	set s to t as text
	set AppleScript's text item delimiters to "'"
	set parts to every text item of s
	set AppleScript's text item delimiters to "'\\''"
	set escaped to parts as text
	set AppleScript's text item delimiters to ""
	return "'" & escaped & "'"
end shellQuote

on appendTextLine(filePath, lineText)
	set fm to current application's NSFileManager's defaultManager()
	set contentText to (lineText as text) & linefeed
	set contentData to (current application's NSString's stringWithString:contentText)'s dataUsingEncoding:(current application's NSUTF8StringEncoding)
	if (fm's fileExistsAtPath:filePath) as boolean then
		set fileHandle to current application's NSFileHandle's fileHandleForWritingAtPath:filePath
		fileHandle's seekToEndOfFile()
		fileHandle's writeData:contentData
		fileHandle's closeFile()
	else
		(contentData's writeToFile:filePath atomically:true)
	end if
end appendTextLine

on desktopPath()
	set homePath to (current application's NSHomeDirectory()) as text
	if homePath does not end with "/" then set homePath to homePath & "/"
	return homePath & "Desktop/"
end desktopPath

on nowSeconds()
	set nowDate to current application's NSDate's |date|()
	return ((nowDate's timeIntervalSince1970()) as real)
end nowSeconds

on nowDateText()
	set formatter to current application's NSDateFormatter's alloc()'s init()
	formatter's setDateFormat:"yyyy-MM-dd HH:mm:ss"
	set nowDate to current application's NSDate's |date|()
	return (formatter's stringFromDate:nowDate) as text
end nowDateText

on modalResponseCode(responseValue)
	try
		return responseValue as integer
	on error
		try
			return (responseValue's integerValue()) as integer
		on error
			return 0
		end try
	end try
end modalResponseCode

on firstAlertButtonCode()
	return 1000
end firstAlertButtonCode

on isExecutableFile(p)
	set fm to current application's NSFileManager's defaultManager()
	return (fm's isExecutableFileAtPath:p) as boolean
end isExecutableFile

on isRegularFile(p)
	set fm to current application's NSFileManager's defaultManager()
	if (fm's fileExistsAtPath:p) as boolean is false then return false
	set attrs to fm's attributesOfItemAtPath:p |error|:(missing value)
	if attrs is missing value then return false
	set fileTypeValue to attrs's objectForKey:(current application's NSFileType)
	if fileTypeValue is missing value then return false
	return ((fileTypeValue as text) is (current application's NSFileTypeRegular as text))
end isRegularFile

on isDirectoryPath(p)
	set fm to current application's NSFileManager's defaultManager()
	if (fm's fileExistsAtPath:p) as boolean is false then return false
	set attrs to fm's attributesOfItemAtPath:p |error|:(missing value)
	if attrs is missing value then return false
	set fileTypeValue to attrs's objectForKey:(current application's NSFileType)
	if fileTypeValue is missing value then return false
	return ((fileTypeValue as text) is (current application's NSFileTypeDirectory as text))
end isDirectoryPath

on startProgressWindow(titleText, totalCount)
	set nowTs to my nowSeconds()
	return {title:titleText, total:totalCount, startDate:nowTs}
end startProgressWindow

on advanceProgressWindow(p)
	return p
end advanceProgressWindow

on endProgressWindow(p)
	return
end endProgressWindow

on showProgressSummary(p, outDir, totalCount, elapsedText, logInfo)
	my runOSA({"display dialog " & my appleScriptString("Listo" & return & return & "Archivos guardados en:" & return & outDir & return & return & "Procesadas: " & totalCount & "  Tiempo: " & elapsedText & return & return & logInfo) & " buttons {\"OK\"} default button \"OK\""})
end showProgressSummary

on formatETA(secondsVal)
	set s to secondsVal as integer
	if s < 0 then set s to 0
	set h to s div 3600
	set m to (s mod 3600) div 60
	set ss to s mod 60
	if h > 0 then
		return (h as text) & ":" & my pad2(m) & ":" & my pad2(ss)
	end if
	return my pad2(m) & ":" & my pad2(ss)
end formatETA

on pad2(n)
	if n < 10 then return "0" & (n as text)
	return n as text
end pad2

on formatPercent(doneCount, totalCount)
	if totalCount is 0 then return "0%"
	set pctVal to ((doneCount / totalCount) * 100) as integer
	if pctVal < 0 then set pctVal to 0
	if pctVal > 100 then set pctVal to 100
	return (pctVal as text) & "%"
end formatPercent

on makeLabel(t, x, y)
	set lbl to current application's NSTextField's alloc()'s initWithFrame:{{x, y}, {130, 24}}
	lbl's setStringValue:t
	lbl's setBezeled:false
	lbl's setDrawsBackground:false
	lbl's setEditable:false
	lbl's setSelectable:false
	return lbl
end makeLabel

on makeField(t, x, y, w)
	set fld to current application's NSTextField's alloc()'s initWithFrame:{{x, y}, {w, 24}}
	fld's setStringValue:t
	return fld
end makeField

on makePopup(itemsList, selectedItem, x, y, w)
	set pop to current application's NSPopUpButton's alloc()'s initWithFrame:{{x, y}, {w, 24}} pullsDown:false
	repeat with itemTitle in itemsList
		pop's addItemWithTitle:(itemTitle as text)
	end repeat
	try
		pop's selectItemWithTitle:(selectedItem as text)
	end try
	return pop
end makePopup

on toInt(t, fallbackVal)
	try
		return (t as integer)
	on error
		return fallbackVal as integer
	end try
end toInt
