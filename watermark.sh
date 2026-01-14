use framework "AppKit"
use framework "Foundation"
use scripting additions

on run {input, parameters}

	-- Normalizar input (Automator puede pasar missing value, ruta en texto o un solo item)
	set input to my normalizeInput(input)
	set input to my filterExistingFiles(input)
	if input is {} then
		set lastImgDir to my getPref("lastImgDir", "")
		if lastImgDir is not "" and my pathExists(lastImgDir) then
			set input to choose file with prompt "Selecciona las imagenes a procesar:" of type {"public.image"} default location ((POSIX file lastImgDir) as alias) with multiple selections allowed
		else
			set input to choose file with prompt "Selecciona las imagenes a procesar:" of type {"public.image"} with multiple selections allowed
		end if
	end if

	-- Elegir logo (PNG)
	set lastLogoDir to my getPref("lastLogoDir", "")
	if lastLogoDir is not "" and my pathExists(lastLogoDir) then
		set wmAlias to choose file with prompt "Elige tu logo (PNG con fondo transparente):" default location ((POSIX file lastLogoDir) as alias)
	else
		set wmAlias to choose file with prompt "Elige tu logo (PNG con fondo transparente):"
	end if
	set wmPath to POSIX path of wmAlias

	-- Ruta ImageMagick
	set magickPath to "/opt/homebrew/bin/magick"
	try
		do shell script "/bin/test -x " & quoted form of magickPath
	on error
		set magickPath to "/usr/local/bin/magick"
		try
			do shell script "/bin/test -x " & quoted form of magickPath
		on error
			display dialog "No encontre ImageMagick (magick).\n\nInstalalo con:\nbrew install imagemagick" buttons {"OK"} default button "OK"
			return input
		end try
	end try

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
		set wStr to do shell script quoted form of magickPath & " identify -format %w " & quoted form of previewSrc
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
			do shell script "/bin/zsh -lc " & quoted form of previewCmd
			do shell script "/usr/bin/open -a Preview " & quoted form of previewPath
		on error errMsg
			display dialog "Error generando previsualizacion:\n\n" & errMsg buttons {"OK"} default button "OK"
			return input
		end try

		set resp to display dialog "Previsualizacion generada.\n\nVerifica la primera imagen y confirma si los parametros son correctos." buttons {"Modificar", "Aceptar"} default button "Aceptar"
		if button returned of resp is "Aceptar" then set approvedPreview to true
	end repeat

	-- Carpeta destino
	set lastOutDir to my getPref("lastOutDir", "")
	if lastOutDir is not "" and my pathExists(lastOutDir) then
		set outFolder to choose folder with prompt "Selecciona la carpeta destino:" default location ((POSIX file lastOutDir) as alias)
	else
		set outFolder to choose folder with prompt "Selecciona la carpeta destino:"
	end if
	set outDir to POSIX path of outFolder
	if outDir does not end with "/" then set outDir to outDir & "/"

	-- Log (solo si hay errores)
	set logPath to (POSIX path of (path to desktop folder)) & "watermark_app_log.txt"
	set logCreated to false
	set errorCount to 0

	set startTime to (current date)
	set totalCount to count of input

	-- Barra de progreso
	set progress to my startProgressWindow("Procesando imagenes...", totalCount)

	repeat with f in input
		my advanceProgressWindow(progress)
		set inPath to my toPosixPath(f)
		set baseName to my filenameNoExt(inPath)
		set outPath to outDir & baseName & "_wm.jpg"

		-- Obtener ancho de la foto
		set wStr to do shell script quoted form of magickPath & " identify -format %w " & quoted form of inPath
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
			do shell script "/bin/zsh -lc " & quoted form of cmd
		on error errMsg
			if logCreated is false then
				do shell script "/bin/echo " & quoted form of ("---- RUN " & (current date as text) & " ----") & " >> " & quoted form of logPath
				set logCreated to true
			end if
			set errorCount to errorCount + 1
			do shell script "/bin/echo " & quoted form of ("ERROR: " & inPath & " :: " & errMsg) & " >> " & quoted form of logPath
			display dialog "Error procesando:\n" & inPath & "\n\nDetalle:\n" & errMsg buttons {"OK"} default button "OK"
		end try
	end repeat

	my endProgressWindow(progress)
	set elapsedSec to ((current date) - startTime) as real
	set elapsedText to my formatETA(elapsedSec)

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
	display dialog "Listo.\nArchivos guardados en:\n" & outDir & "\n\nProcesadas: " & totalCount & "\nTiempo: " & elapsedText & "\n\n" & logInfo buttons {"OK"} default button "OK"
	return input
end run


-- Helpers
on askNumber(promptText, defaultValue)
	set d to display dialog promptText default answer (defaultValue as text) buttons {"Cancelar", "OK"} default button "OK"
	if button returned of d is "Cancelar" then error number -128
	set t to text returned of d
	try
		set n to t as integer
	on error
		set n to defaultValue as integer
	end try
	return n
end askNumber

on filenameNoExt(p)
	set bn to do shell script "/usr/bin/basename " & quoted form of p
	set nameOnly to do shell script "/bin/echo " & quoted form of bn & " | /usr/bin/sed 's/\\.[^.]*$//'"
	return nameOnly
end filenameNoExt

on parentDirPath(p)
	set dirPath to do shell script "/usr/bin/dirname " & quoted form of p
	if dirPath does not end with "/" then set dirPath to dirPath & "/"
	return dirPath
end parentDirPath

on pathExists(p)
	try
		do shell script "/bin/test -d " & quoted form of p
		return true
	on error
		return false
	end try
end pathExists

-- Preferencias persistentes (defaults)
on getPref(key, defaultValue)
	try
		return do shell script "defaults read com.watermark.app " & key
	on error
		return defaultValue
	end try
end getPref

on setPref(key, value)
	do shell script "defaults write com.watermark.app " & key & " " & quoted form of value
end setPref

on promptParams(defaultPct, defaultOpacity, defaultMargin, defaultQuality, defaultPos)
	-- Ventana con 5 campos
	set alert to current application's NSAlert's alloc()'s init()
	alert's setMessageText:"Parametros de marca de agua"
	alert's setInformativeText:"Configura los valores y presiona Continuar."
	alert's addButtonWithTitle:"Continuar"
	alert's addButtonWithTitle:"Cerrar"

	-- Vista contenedora
	set boxW to 360
	set boxH to 185
	set v to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {boxW, boxH}}

	-- Labels + fields
	set lbl1 to my makeLabel("Tamano (%)", 0, 150)
	set fld1 to my makeField(defaultPct as text, 140, 145, 200)

	set lbl2 to my makeLabel("Opacidad (0-100)", 0, 115)
	set fld2 to my makeField(defaultOpacity as text, 140, 110, 200)

	set lbl3 to my makeLabel("Margen (px)", 0, 80)
	set fld3 to my makeField(defaultMargin as text, 140, 75, 200)

	set lbl4 to my makeLabel("Calidad JPG (80-100)", 0, 45)
	set fld4 to my makeField(defaultQuality as text, 140, 40, 200)

	set lbl5 to my makeLabel("Posicion", 0, 10)
	set popPos to my makePopup({"Arriba izquierda", "Arriba derecha", "Abajo izquierda", "Abajo derecha", "Centro"}, defaultPos, 140, 5, 200)

	v's addSubview:lbl1
	v's addSubview:fld1
	v's addSubview:lbl2
	v's addSubview:fld2
	v's addSubview:lbl3
	v's addSubview:fld3
	v's addSubview:lbl4
	v's addSubview:fld4
	v's addSubview:lbl5
	v's addSubview:popPos

	alert's setAccessoryView:v

	set response to alert's runModal()
	if response is not (current application's NSAlertFirstButtonReturn) then error number -128

	-- Leer valores
	set pctStr to (fld1's stringValue()) as text
	set opStr to (fld2's stringValue()) as text
	set marginStr to (fld3's stringValue()) as text
	set qualityStr to (fld4's stringValue()) as text
	set posStr to (popPos's titleOfSelectedItem()) as text

	-- Validar / convertir a int con fallback
	set pctVal to my toInt(pctStr, defaultPct)
	set opVal to my toInt(opStr, defaultOpacity)
	set marginVal to my toInt(marginStr, defaultMargin)
	set qualityVal to my toInt(qualityStr, defaultQuality)

	-- Opcional: limites razonables
	if pctVal < 1 then set pctVal to 1
	if opVal < 0 then set opVal to 0
	if opVal > 100 then set opVal to 100
	if marginVal < 0 then set marginVal to 0
	if qualityVal < 80 then set qualityVal to 80
	if qualityVal > 100 then set qualityVal to 100

	return {wmPct:pctVal, wmOpacity:opVal, wmMargin:marginVal, jpgQuality:qualityVal, posChoice:posStr}
end promptParams

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
			do shell script "/bin/test -f " & quoted form of p
			set end of outList to p
		on error
			-- skip invalid items
		end try
	end repeat
	return outList
end filterExistingFiles

on startProgressWindow(titleText, totalCount)
	set alert to current application's NSAlert's alloc()'s init()
	alert's setMessageText:titleText
	alert's addButtonWithTitle:"Cerrar"

	set boxW to 360
	set boxH to 70
	set v to current application's NSView's alloc()'s initWithFrame:{{0, 0}, {boxW, boxH}}

	set bar to current application's NSProgressIndicator's alloc()'s initWithFrame:{{20, 20}, {320, 20}}
	bar's setIndeterminate:false
	bar's setMinValue:0
	bar's setMaxValue:totalCount
	bar's setDoubleValue:0
	bar's setUsesThreadedAnimation:false
	bar's startAnimation:(missing value)

	set lbl to current application's NSTextField's alloc()'s initWithFrame:{{20, 45}, {320, 20}}
	lbl's setStringValue:"0%  ETA: --"
	lbl's setBezeled:false
	lbl's setDrawsBackground:false
	lbl's setEditable:false
	lbl's setSelectable:false

	v's addSubview:bar
	v's addSubview:lbl

	alert's setAccessoryView:v
	-- Mostrar sin bloquear el loop
	set mainWin to current application's NSApp's mainWindow
	if mainWin is missing value then set mainWin to current application's NSApp's keyWindow
	if mainWin is not missing value then
		alert's beginSheetModalForWindow:mainWin completionHandler:(missing value)
	else
		-- Fallback: mostrar igual, aunque sea modal
		alert's runModal()
	end if

	return {alert:alert, bar:bar, label:lbl, startDate:(current date), total:totalCount, lastDate:(current date), lastCount:0, rate:missing value}
end startProgressWindow

on advanceProgressWindow(p)
	try
		set bar to bar of p
		bar's incrementBy:1
		bar's display()

		set doneCount to (bar's doubleValue()) as real
		set totalCount to total of p
		if doneCount > 0 then
			-- Suavizar usando promedio exponencial para evitar saltos
			set nowDate to (current date)
			set lastDateVal to lastDate of p
			set lastCountVal to lastCount of p
			set deltaCount to doneCount - lastCountVal
			set deltaTime to (nowDate - lastDateVal) as real
			if deltaCount > 0 and deltaTime > 0 then
				set instantRate to deltaTime / deltaCount
				if rate of p is missing value then
					set rate of p to instantRate
				else
					set alpha to 0.2
					set rate of p to ((alpha * instantRate) + ((1 - alpha) * (rate of p)))
				end if
				set lastDate of p to nowDate
				set lastCount of p to doneCount
			end if

			set pct to my formatPercent(doneCount, totalCount)
			if rate of p is not missing value then
				set remaining to (rate of p) * (totalCount - doneCount)
				set etaText to my formatETA(remaining)
				set lbl to label of p
				lbl's setStringValue:(pct & "  ETA: " & etaText)
				lbl's display()
			else
				set lbl to label of p
				lbl's setStringValue:(pct & "  ETA: --")
				lbl's display()
			end if
		end if

		delay 0.01
	end try
end advanceProgressWindow

on endProgressWindow(p)
	try
		set alert to alert of p
		set win to alert's window()
		if win is missing value then return
		win's orderOut:(missing value)
	end try
end endProgressWindow

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
