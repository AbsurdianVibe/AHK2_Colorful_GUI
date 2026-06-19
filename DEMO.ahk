#Requires AutoHotkey v2.0
#Include AHK2ColorfulGUI.ahk
;throw Error("CRITICAL_TEST_CRASH")

; Set dark theme base color, or any color you want!
SilnikGUI.Konfiguruj("2B2B2B")
TotalScale := 1.2
SilnikGUI.Statics.GlobFont.Name := "times new roman"
;todo what to do witch GlobFont.Size?????
SilnikGUI.Statics.GlobFont.Size := 11
SilnikGUI.Statics.TotalScale := TotalScale

App := SilnikGUI("AHK2 Colorful GUI - Feature Demo", "+MinSize200x200", {
    MainGUI: true,
    CSBarV: 1,
    CSBarH: 1,
    GruboscRamki: 2,
    ResizeMarg: 8,
    PadD: 20,
    PadR: 20,
    PadL: 20
})
PadL := 20
; --- Header ---
Welcome := App.Add("Text", "X" . padL + 10 . "  y20", "Welcome to AHK2ColorfulGUI Demo", 1, 16)
Welcome.HoverAction := (*) => SilnikGUI.CustomTooltip("This is anchor type tooltip", { DelayON: 1000, czas: 3000, trybPozycji: Welcome })
; App.Stan.ChildGui.SetFont("s10 norm")
; App.Stan.ChildGui.SetFont("s12 italic")
Welcome2 := App.Add("Text", "x" . padL + 10. " y+15 cAAAAAA", "--- Input Fields ---")
Welcome2.GetPos(, , &W2W, &W2H)
Welcome2.Move(320, 50, , , 1)

; String Validation (Type 2)
ConfigLine1 := App.DodajWierszKonfiguracji("standard mode:", "Guest User", {
    trybWalidacji: 2,
    SzerPola: 200,
    SzerText: 90,
    pozycja: "y+20 xp"
})

; Integer Validation (Type 0) with limits and scroll step
ConfigLine2 := App.DodajWierszKonfiguracji("Integer mode:", 50, {
    trybWalidacji: 0,
    minVal: 0,
    maxVal: 100,
    skok: 5,
    SzerText: 90,
    SzerPola: 100,
    pozycja: "y+10 xp"
})

; Float Validation (Type 1) with limits
ConfigLine3 := App.DodajWierszKonfiguracji("UI Scale:", SilnikGUI.Statics.TotalScale, {
    trybWalidacji: 1,
    minVal: 0.1,
    maxVal: 5.0,
    skok: 0.02,
    SzerText: 90,
    SzerPola: 100,
    pozycja: "y+10 xp"
})
ConfigLine3.OnEvent("Change", (*) => SilnikGUI.PrzeskalujWszystko(ConfigLine3.Value))
OgVScroll := ConfigLine3.VScrollAction
ConfigLine3.VScrollAction := (ctrl, dir) => (OgVScroll(ctrl, dir), SilnikGUI.PrzeskalujWszystko(ctrl.Value))

; Multiline (Type 3)
ConfigLine4 := App.DodajWierszKonfiguracji("Multiline mode:", "Line 1: AHK is great!`nLine 2: ColorfulGUI is awesome!", {
    trybWalidacji: 3,
    WysInput: 2,
    SzerText: 90,
    SzerPola: 250,
    pozycja: "y+10 xp"
})
;only visual frame around several controls (does not move them automaticly)
App.Ramka(ConfigLine1, ConfigLine4, 10)
; --- Toggles and Selectors ---
App.Add("Text", "xm y+20 cAAAAAA", "--- Controls ---") ; .SetFont("s12 italic")

; Checkbox
chk := App.DodajCheckbox("Enable Advanced Mode", { pozycja: "x60", czyZaznaczony: true, InfoRight: 1 })
chk.OnEvent("Click", (ctrl, *) => SilnikGUI.CustomTooltip(ctrl.Value ? "Enabled!" : "Disabled!", { czas: 2000, trybPozycji: "Mouse" }))
ch2 := App.DodajCheckbox("Enable Advanced Mode", { pozycja: "x60", czyZaznaczony: true, InfoRight: 0 })


; DropDown List
App.DDList(["First Option", "Second Option", "Third Option", "Fourth Option"],
    (ctrl, index) => SilnikGUI.CustomTooltip("You selected: " . ctrl.Value, { czas: 2000, trybPozycji: "Mouse" }),
    1, { pos: "xm", padY: 0, pad: 0, sepw: 1, align: "C" }
)
; DropDown List
App.DDList(["First Option", "Second Option", "Third Option", "Fourth Option"],
    (ctrl, index) => SilnikGUI.CustomTooltip("You selected: " . ctrl.Value, { czas: 2000, trybPozycji: "Mouse" }),
    1, { pos: "xm", padX: 5 }
)
; --- Interactive Buttons ---
App.Add("Text", "xm y+20", "--- Dialogs & Tooltips ---") ; .SetFont("s12 italic")

; Custom Error Dialog
App.DodajPrzycisk("Show Error Dialog", (ctrl, *) => (SilnikGUI.OknoBledu("Critical Failure", "This is a demonstration of the custom error dialog.", "Please contact support or try again.", App.GuiObj.Hwnd)), "xm")

; Custom Tooltip
App.DodajPrzycisk("Show Tooltip", (ctrl, *) => (
    SilnikGUI.CustomTooltip("This is a stylized tooltip!`nIt follows the mouse and supports`nmultiple lines.`n.[3].`n...And separators!", { transparent: 0.2, czas: 3000, czyPogrubione: 1 })
), "x+1 yp", , { Pad: 20, PadX: 30 })

; Auto-expanding dialog demo
App.DodajPrzycisk("Dynamic Window", (ctrl, *) => (
    SilnikGUI.CustomTooltip("This window will auto-expand when typing long text.", { czas: 3000, trybPozycji: "Mouse" }),
    ShowDynamicDialog()
), "x+10 yp")

; Tab tracking demo
przyciskRuchomy := App.DodajPrzycisk("Tab tracking demo", (ctrl, *) => ShowTabTrackingDemo(), "x+10 yp w100 h40")
; ptzycikRuchomy.move(20, 425, 146)
przyciskRuchomy.AnchorCtrl.GetPos(, , &W2W, &W2H)
przyciskRuchomy.HoverAction := (*) => SilnikGUI.CustomTooltip("This is anchor type tooltip W: " . W2W . " H: " . W2H, { DelayON: 0, czas: 0, trybPozycji: przyciskRuchomy })
; --- Panels ---
App.Add("Text", "xm y+20", "--- Panels & Scrolling ---") ; .SetFont("s12 italic")

; Nested Scrollable Sub-Panel
SubPanel := App.DodajPanel(2, 1, 1, { PadD: 10 })
SubPanel.Add("Text", "xm", "I am a nested panel!")
Loop 5
    SubPanel.DodajCheckbox("Sub-item " A_Index, { pozycja: "xm" })
SubPanel.PokazPanel(App, "y+10", "w250 h80")

; Scrollable Text Panel
LongText := "This is line 1 inside the text panel........`nThis is line 2.`nKeep scrolling down...`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nLine 4`nLine 5`nLine 6`nLine 7`nLine 8`nEnd of text."
TxtPanel := App.DodajPanelTxt(LongText, 250, 80, { InfiniteLine: 1, pozycja: "yp x+10" })
TxtPanel.Stan.VBar.Thumb.HoverAction := (*) => SilnikGUI.CustomTooltip("Hold CTRL while dragging`nto feel TRUE PRECISION!", { czas: 2000, trybPozycji: "Mouse", czyPogrubione: 1 })
TxtPanel.Stan.HBar.Thumb.HoverAction := (*) => SilnikGUI.CustomTooltip("Try scrolling with the mouse wheel over my", { czas: 2000, trybPozycji: "Mouse", czyPogrubione: 1 })

/**
 * @desc Dynamic demo window (clone of F2 rename window mechanics).
 */
ShowDynamicDialog() {
    ; [NOTE] 'zamknijNaEsc: 2' means the window is destroyed on Esc.
    ; Because of the new State Lock and WinAPI validation, we do not need
    ; any 'early return' checks anymore. The engine automatically returns
    ; a safe proxy object to swallow any duplicate control creation.
    ; Initialization without title bar, fitting width automatically (AutoFitW: 0.99)
    Z := SilnikGUI("DYNAMIC RENAME", "MinSize260x0", { unikalny: "dynamic rename", pokazPasek: 0, createChild: true, zamknijNaEsc: 2, CSBarV: 0, CSBarH: 0, ResizeMarg: 0, GruboscRamki: 2, PadR: 20, PadD: 15, AutoFitW: 0.99 })

    Z.GuiObj.OnEvent("Close", (*) => Z := 0)
    ; Z.GuiObj.SetFont("s10")

    closeAction := (*) => (Z.Zakoncz(), Z := 0)
    Z.DodajWierszKonfiguracji("New name:", "Type a.", { trybWalidacji: 2, pozycja: "x20 yp+15", SzerPola: 100, AutoCenter: true, SzRamki: 2, ResizeEditW: true, obslugaEnter: closeAction })

    btnZapisz := Z.DodajPrzycisk("Save", closeAction, "xm y+20 w100 h30")
    btnAnuluj := Z.DodajPrzycisk("Cancel", closeAction, "yp w100 h30")

    Z.CallbackLayout := (Szer, Off := 0, *) => (
        Sk := A_ScreenDPI / 96,
        RealW := 100 * TotalScale * Sk,
        gap := (Szer - 2 * RealW) / 3,
        btnZapisz.Move(gap + Off, "", "", "", false),
        btnAnuluj.Move(Szer - gap - RealW + Off, "", "", "", false)
    )

    Z.Pokaz()
}

/**
 * @desc Focus tracking demo (Tab key) with widely scattered controls.
 */
ShowTabTrackingDemo() {

    ; [NOTE] 'zamknijNaEsc: 1' means the window hides when Esc is pressed.
    ; Even if the window is just hidden, the WinAPI IsWindow check ensures
    ; it is correctly found. The State Lock then prevents new controls from
    ; being added to the existing GUI, making early returns completely obsolete.
    T := SilnikGUI("Tab Tracking Demo", "MinSize200x200", { unikalny: "TabDemo", pokazPasek: 1, createChild: true, zamknijNaEsc: 1, CSBarV: 1, CSBarH: 1, PadD: 30, PadR: 30 })

    T.GuiObj.OnEvent("Close", (*) => (T.Zakoncz(), T := 0))

    T.DodajWierszKonfiguracji("Step 1:", "Press TAB...", { pozycja: "x20 y20", SzerPola: 120 }) ;
    T.DodajCheckbox("Step 2 (Far Right)", { pozycja: "x600 y150" })
    T.DDList(["Step 3.A", "Step 3.B"], 0, 1, { w: 150, pos: "x50 y500" })
    T.DodajPrzycisk("Step 4 (Far Bottom)", (*) => SilnikGUI.CustomTooltip("Done!", { czas: 2000, trybPozycji: "Mouse" }), "x500 y800 w150 h30")

    T.Pokaz("w300 h300")
}

; Render main window
App.Pokaz("y20")