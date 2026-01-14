use AppleScript version "2.7"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property prefsDomain : "com.watermark.app"

on run
	set inputFiles to {}
	try
		set inputFiles to (choose file with prompt "Selecciona las imagenes a procesar:" of type {"public.image"} with multiple selections allowed)
	on error number -128
		return
	end try
	my main(inputFiles)
end run

on open droppedItems
	my main(droppedItems)
end open

on main(inputItems)
	if inputItems is {} then
		display dialog "No recibi imagenes." buttons {"OK"} default button "OK"
		return
	end if

	set wmAlias to choose file with prompt "Elige tu logo (PNG con fondo transparente):"
	set wmPath to POSIX path of wmAlias

	set dPct to my toInt(my getPref("wmPct", "18"), 18)
	set dOp to my toInt(my getPref("wmOpacity", "35"), 35)
	set dMargin to my toInt(my getPref("wmMargin", "30"), 30)
	set dQ to my toInt(my getPref("jpgQuality", "98"), 98)
	set dPos to my getPref("position", "Arriba derecha")

	set p to my showParamsOnMainThread(dPct, dOp, dMargin, dQ, dPos)
	if p is missing value then return

	set wmPct to wmPct of p
	set wmOpacity to wmOpacity of p
	set wmMargin to wmMargin of p
	set jpgQuality to jpgQuality of p
	set posChoice to position of p

	set gravity to my positionToGravity(posChoice)

	set outFolder to choose folder with prompt "Selecciona la carpeta destino:"
	set outDir to POSIX path of outFolder
	if outDir does not end with "/" then set outDir to outDir & "/"

	set magickPath to "/opt/homebrew/bin/magick"
	try
		do shell script "/bin/test -x " & quoted form of magickPath
	on error
		set magickPath to "/usr/local/bin/magick"
		try
			do shell script "/bin/test -x " & quoted form of magickPath
		on error
			display dialog "No encontre ImageMagick (magick)." & return & return & "Instalalo con:" & return & "brew install imagemagick" buttons {"OK"} default button "OK"
			return
		end try
	end try

	set logPath to (POSIX path of (path to desktop folder)) & "watermark_app_log.txt"
	do shell script "/bin/echo " & quoted form of ("---- RUN " & (current date as text) & " ----") & " >> " & quoted form of logPath

	repeat with f in inputItems
		set inPath to POSIX path of f
		set baseName to my filenameNoExt(inPath)
		set outPath to outDir & baseName & "_wm.jpg"

		set wStr to do shell script quoted form of magickPath & " identify -format %w " & quoted form of inPath
		set wInt to wStr as integer
		set wmW to (wInt * wmPct) div 100
		if wmW < 1 then set wmW to 1

		set cmd to quoted form of magickPath & " " & quoted form of inPath & " -auto-orient " & "\\( " & quoted form of wmPath & " -alpha on -resize " & wmW & "x \\) " & "-gravity " & gravity & " -geometry +" & wmMargin & "+" & wmMargin & " " & "-compose dissolve -define compose:args=" & wmOpacity & " -composite " & "-sampling-factor 4:4:4 -quality " & jpgQuality & " " & quoted form of outPath

		try
			do shell script "/bin/zsh -lc " & quoted form of cmd
		on error errMsg
			do shell script "/bin/echo " & quoted form of ("ERROR: " & inPath & " :: " & errMsg) & " >> " & quoted form of logPath
			display dialog "Error procesando:" & return & inPath & return & return & "Detalle:" & return & errMsg buttons {"OK"} default button "OK"
		end try
	end repeat

	my setPref("wmPct", wmPct as text)
	my setPref("wmOpacity", wmOpacity as text)
	my setPref("wmMargin", wmMargin as text)
	my setPref("jpgQuality", jpgQuality as text)
	my setPref("position", posChoice as text)

	display dialog "Listo." & return & "Archivos guardados en:" & return & outDir & return & return & "Log:" & return & logPath buttons {"OK"} default button "OK"
end main

on showParamsOnMainThread(dPct, dOp, dMargin, dQ, dPos)
	script FormRunner
		property parent : current application's NSObject
		property pctDefault : 18
		property opDefault : 35
		property marginDefault : 30
		property qDefault : 98
		property posDefault : "Arriba derecha"
		property result : missing value

		on showForm_(dummy)
			set ca to current application's
			ca's NSApplication's sharedApplication()
			ca's NSApp's activateIgnoringOtherApps:true

			set alert to (ca's NSAlert's alloc()'s init())
			alert's setMessageText:"Parametros de marca de agua"
			alert's setInformativeText:"Configura valores y presiona Continuar."
			alert's addButtonWithTitle:"Continuar"
			alert's addButtonWithTitle:"Cancelar"

			set v to (ca's NSView's alloc()'s initWithFrame:{{0, 0}, {470, 215}})

			set lbl1 to my makeLabel("Tamano (% del ancho)", 0, 175)
			set fld1 to my makeField((pctDefault as text), 250, 170, 200)

			set lbl2 to my makeLabel("Opacidad (0-100)", 0, 140)
			set fld2 to my makeField((opDefault as text), 250, 135, 200)

			set lbl3 to my makeLabel("Margen (px)", 0, 105)
			set fld3 to my makeField((marginDefault as text), 250, 100, 200)

			set lbl4 to my makeLabel("Calidad JPG (80-100)", 0, 70)
			set fld4 to my makeField((qDefault as text), 250, 65, 200)

			set lbl5 to my makeLabel("Posicion", 0, 35)
			set pop to (ca's NSPopUpButton's alloc()'s initWithFrame:{{250, 30}, {200, 26}})
			pop's addItemsWithTitles:({"Arriba izquierda", "Arriba derecha", "Abajo izquierda", "Abajo derecha", "Centro"})
			pop's selectItemWithTitle:(posDefault)

			v's addSubview:lbl1
			v's addSubview:fld1
			v's addSubview:lbl2
			v's addSubview:fld2
			v's addSubview:lbl3
			v's addSubview:fld3
			v's addSubview:lbl4
			v's addSubview:fld4
			v's addSubview:lbl5
			v's addSubview:pop

			alert's setAccessoryView:v

			set response to alert's runModal()
			if response is not (ca's NSAlertFirstButtonReturn) then
				set result to missing value
				return
			end if

			set pctVal to my clampInt((fld1's stringValue() as text), pctDefault, 1, 100)
			set opVal to my clampInt((fld2's stringValue() as text), opDefault, 0, 100)
			set marginVal to my clampInt((fld3's stringValue() as text), marginDefault, 0, 5000)
			set qVal to my clampInt((fld4's stringValue() as text), qDefault, 80, 100)
			set posVal to (pop's titleOfSelectedItem()) as text

			set result to {wmPct:pctVal, wmOpacity:opVal, wmMargin:marginVal, jpgQuality:qVal, position:posVal}
		end showForm_

		on makeLabel(t, x, y)
			set ca to current application's
			set lbl to (ca's NSTextField's alloc()'s initWithFrame:{{x, y}, {245, 24}})
			lbl's setStringValue:t
			lbl's setBezeled:false
			lbl's setDrawsBackground:false
			lbl's setEditable:false
			lbl's setSelectable:false
			return lbl
		end makeLabel

		on makeField(t, x, y, w)
			set ca to current application's
			set fld to (ca's NSTextField's alloc()'s initWithFrame:{{x, y}, {w, 24}})
			fld's setStringValue:t
			return fld
		end makeField

		on clampInt(txt, fallbackVal, minVal, maxVal)
			set n to fallbackVal as integer
			try
				set n to (txt as integer)
			end try
			if n < minVal then set n to minVal
			if n > maxVal then set n to maxVal
			return n
		end clampInt
	end script

	set r to FormRunner's alloc()'s init()
	set r's pctDefault to dPct
	set r's opDefault to dOp
	set r's marginDefault to dMargin
	set r's qDefault to dQ
	set r's posDefault to dPos

	r's performSelectorOnMainThread_withObject_waitUntilDone_("showForm:", missing value, true)
	return r's result()
end showParamsOnMainThread

on toInt(v, fallbackVal)
	try
		return v as integer
	on error
		try
			return (v as text) as integer
		on error
			return fallbackVal as integer
		end try
	end try
end toInt

on filenameNoExt(p)
	set bn to do shell script "/usr/bin/basename " & quoted form of p
	set nameOnly to do shell script "/bin/echo " & quoted form of bn & " | /usr/bin/sed 's/\\.[^.]*$//'"
	return nameOnly
end filenameNoExt

on positionToGravity(posChoice)
	if posChoice is "Arriba izquierda" then return "northwest"
	if posChoice is "Arriba derecha" then return "northeast"
	if posChoice is "Abajo izquierda" then return "southwest"
	if posChoice is "Abajo derecha" then return "southeast"
	return "center"
end positionToGravity

on getPref(key, defaultValue)
	try
		return do shell script "defaults read " & prefsDomain & " " & key
	on error
		return defaultValue
	end try
end getPref

on setPref(key, value)
	do shell script "defaults write " & prefsDomain & " " & key & " " & quoted form of (value as text)
end setPref
